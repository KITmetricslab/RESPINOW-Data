import numpy as np
import pandas as pd
import requests
from pathlib import Path
from epiweeks import Week


def ages_by_group(age_group):
    if age_group == '80+':
        return {'A80.': '80+'}
    limits = age_group.split('-')
    keys = [f'A{a:02d}..{a:02d}' for a in range(int(limits[0]), int(limits[1]) + 1)]
    return dict.fromkeys(keys, age_group)


def process_state_file(df):
    # add iso date (end date of the corresponding week)
    df['date'] = df.apply(lambda x: Week(x.year, x.week, system='iso').enddate(), axis=1)

    df = df.rename(columns={'stratum': 'location'})

    # fix state names and replace with abbreviations
    df.location = df.location.replace({'Ã.': 'ü', '\.': '-'}, regex=True)
    df.location = df.location.replace(LOCATION_CODES)

    # fill in age_group
    df['age_group'] = '00+'

    df = df[['date', 'year', 'week', 'location', 'age_group', 'value']]
    df = df.sort_values(['location', 'age_group', 'date'], ignore_index=True)

    return df


def process_age_file(df):
    # add iso date (end date of the corresponding iso week)
    df['date'] = df.apply(lambda x: Week(x.year, x.week, system='iso').enddate(), axis=1)

    df = df.rename(columns={'stratum': 'age_group'})

    # drop entries with unknown age group
    df = df[df.age_group != "Unbekannt"]

    # summarize age groups (from yearly resolution to specified groups)
    df.age_group = df.age_group.replace(AGE_DICT)
    df = df.groupby(['date', 'year', 'week', 'age_group'], as_index=False)['value'].sum()

    # compute sum for age group 00+
    df_all = df.groupby(['date', 'year', 'week'], as_index=False)['value'].sum()
    df_all['age_group'] = '00+'

    df = pd.concat([df, df_all])

    # fill in location
    df['location'] = 'DE'

    df = df[['date', 'year', 'week', 'location', 'age_group', 'value']]
    df = df.sort_values(['location', 'age_group', 'date'], ignore_index=True)

    return df


def load_data(disease, date):
    try:
        df1 = pd.read_csv(f"{PATH}/{disease}/{disease}-states-{date}.csv")
        df2 = pd.read_csv(f"{PATH}/{disease}/{disease}-age-{date}.csv")

        df1 = process_state_file(df1)
        df2 = process_age_file(df2)

        df = pd.concat([df1, df2])
        df = df.sort_values(['location', 'age_group', 'date'], ignore_index=True)

        return df

    except:
        return None


def add_iso_dates(df):
    """
    Adds iso_week, iso_year and iso_date (end date of the week) to dataframe.
    """
    df['iso_week'] = df.date.apply(lambda x: Week.fromdate(x, system='iso').week)
    df['iso_year'] = df.date.apply(lambda x: Week.fromdate(x, system='iso').year)
    df['iso_date'] = df.apply(lambda x: Week(x.iso_year, x.iso_week, system='iso'), axis=1)

    return df


# Todo: Check if there's a difference for age/state
def list_all_files(disease, stratum='state'):
    # download all files from repo
    url = 'https://api.github.com/repos/KITmetricslab/nowcasting-data/git/trees/main?recursive=1'
    r = requests.get(url)
    res = r.json()

    # filter relevant files
    files = sorted([file['path'] for file in res['tree'] if (file['path'].startswith(disease) and
                                                             file['path'].endswith('.csv') and
                                                             stratum in file['path'])])

    # create dataframe so we can easily select files by date
    df_files = pd.DataFrame({'filename': files})

    # extract date from filename
    df_files['date'] = df_files.filename.str[-14:-4]
    df_files.date = pd.to_datetime(df_files.date)

    df_files = add_iso_dates(df_files)
    df_files['end_date'] = df_files.iso_date.apply(lambda x: x.enddate())

    # only keep latest file per week
    df_files = df_files.sort_values('date').groupby(['iso_year', 'iso_week']).tail(1).reset_index(drop=True)
    
    # remove current week as the data might not be final yet
    current_week = Week.thisweek(system='iso')
    df_files = df_files[df_files.iso_date != current_week]
    
    # only consider files that have not been downloaded before
    path = Path(f'../data/Survstat/{DISEASE_DICT[disease]}/')
    existing_dates = pd.unique([f.name[:10] for f in path.glob('**/*') if f.name.endswith('.csv')])
    df_files = df_files[~df_files.end_date.astype(str).isin(existing_dates)]

    return df_files


PATH = 'https://raw.githubusercontent.com/KITmetricslab/nowcasting-data/main/'

LOCATION_CODES = {'Deutschland': 'DE',
                  'Schleswig-Holstein': 'DE-SH',
                  'Hamburg': 'DE-HH',
                  'Niedersachsen': 'DE-NI',
                  'Bremen': 'DE-HB',
                  'Nordrhein-Westfalen': 'DE-NW',
                  'Hessen': 'DE-HE',
                  'Rheinland-Pfalz': 'DE-RP',
                  'Baden-Württemberg': 'DE-BW',
                  'Bayern': 'DE-BY',
                  'Saarland': 'DE-SL',
                  'Berlin': 'DE-BE',
                  'Brandenburg': 'DE-BB',
                  'Mecklenburg-Vorpommern': 'DE-MV',
                  'Sachsen': 'DE-SN',
                  'Sachsen-Anhalt': 'DE-ST',
                  'Thüringen': 'DE-TH'}

AGE_GROUPS = ['00+', '00-04', '05-14', '15-34', '35-59', '60-79', '80+']

AGE_DICT = dict()
for age_group in AGE_GROUPS[1:]:
    AGE_DICT.update(ages_by_group(age_group))

DISEASE_DICT = {
    'Seasonal_Influenza' : 'influenza',
    'RSV_Infection' : 'rsv',
    'Pneumococcal_Disease' : 'pneumococcal'
}


for disease in disease_dict.keys():
    print("____________________")
    print(disease)
    df_files = list_all_files(disease)
    for index, row in df_files.iterrows():
        print("Processing:", row.filename)
        df = load_data(disease, row.date.date())
        target_path = f'../data/Survstat/{DISEASE_DICT[disease]}/{row.end_date}-survstat-{DISEASE_DICT[disease]}.csv'
        df.to_csv(target_path, index = False)
        print("Saving to:", target_path)
