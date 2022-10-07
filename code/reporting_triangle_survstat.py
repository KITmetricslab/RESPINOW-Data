import numpy as np
import pandas as pd
import requests
from epiweeks import Week
from tqdm.auto import tqdm


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

    # only keep latest file per week
    df_files = df_files.sort_values('date').groupby(['iso_year', 'iso_week']).tail(1).reset_index(drop=True)

    return df_files


def get_relevant_dates(df_files):
    # map iso_date to date of the latest available file of the corresponding week
    date_dict = dict(zip(df_files.iso_date, df_files.date))

    max_date = df_files.iso_date.max().enddate()
    min_date = df_files.iso_date.min().enddate()

    dates = pd.date_range(min_date, max_date, freq="1W")
    dates = [Week.fromdate(d, system='iso') for d in dates]

    # remove current week as the data might not be available/final yet
    current_week = Week.thisweek(system='iso')
    if current_week in dates:
        dates.remove(current_week)

    return date_dict, dates


def make_placeholder(date,
                     states=['DE-BB', 'DE-BE', 'DE-BW', 'DE-BY', 'DE-HB', 'DE-HE',
                             'DE-HH', 'DE-MV', 'DE-NI', 'DE-NW', 'DE-RP', 'DE-SH', 'DE-SL',
                             'DE-SN', 'DE-ST', 'DE-TH'],
                     age_groups=['00+', '00-04', '05-14', '15-34', '35-59', '60-79', '80+']):
    df_age_groups = pd.DataFrame({'date': date.enddate(),
                                  'year': date.year,
                                  'week': date.week,
                                  'location': 'DE',
                                  'age_group': age_groups,
                                  'value': np.nan})

    df_states = pd.DataFrame({'date': date.enddate(),
                              'year': date.year,
                              'week': date.week,
                              'location': states,
                              'age_group': '00+',
                              'value': np.nan})

    return pd.concat([df_age_groups, df_states])


def make_template(disease, dates):
    if disease == 'RSV_Infection':
        states = ['DE-SN']
    else:
        states = ['DE-BB', 'DE-BE', 'DE-BW', 'DE-BY', 'DE-HB', 'DE-HE',
                  'DE-HH', 'DE-MV', 'DE-NI', 'DE-NW', 'DE-RP', 'DE-SH', 'DE-SL',
                  'DE-SN', 'DE-ST', 'DE-TH']

    dfs = []
    for d in dates:
        df = make_placeholder(date=d, states=states)
        dfs.append(df)
    df = pd.concat(dfs, ignore_index=True)
    df = df.drop(columns=['value'])

    return df


def load_delayed_data(disease, date, data_version):
    if data_version in date_dict.keys():
        df = load_data(disease=disease, date=date_dict[data_version].date())
    else:
        df = None

    # select relevant rows if df_temp is not None
    if df is not None:
        df = df[(df.date == date.enddate())]

    return df


def compute_reporting_triangle(disease, max_delay=10):
    df_files = list_all_files(disease)
    global date_dict
    date_dict, dates = get_relevant_dates(df_files)

    df = make_template(disease, dates)
    for delay in tqdm(range(0, max_delay + 1), total=max_delay + 1, desc=f"{disease.replace('_', ' ')}: "):
        relevant_dates = [d for d in dates if d <= max(dates) - delay]
        df_temp = make_template(disease, relevant_dates)
        dfs = []
        for date in relevant_dates:
            data_version = date + delay
            df_delayed = load_delayed_data(disease, date, data_version)
            dfs.append(df_delayed)
        df_delayed = pd.concat(dfs)
        df_temp = df_temp.merge(df_delayed, how='left')

        # we flag missing values to fill later on (not all should be filled to preserve reporting triangle shape)
        df_temp.value = df_temp.value.fillna('to_fill')

        df_temp = df_temp.rename(columns={'value': f'value_{delay}w'})

        df = df.merge(df_temp, how='left')

    # use latest file to compute column for remaining correction beyond the specified largest delay
    df_latest = load_data(disease, dates[-1].enddate())
    df_latest.value = df_latest.value.fillna('to_fill')
    df_latest = df_latest.rename(columns={'value': f'value_>{max_delay}w'})
    df = df.merge(df_latest, how='left')

    # we want to keep the triangle shape and avoid filling the corresponding entries
    df = df.fillna('not_observed')
    df = df.replace({'to_fill': np.nan})

    # if initial report is missing replace with zero
    df.value_0w = df.value_0w.fillna(0)

    # we use forward filling to fill missing values in between
    df = df.fillna(method="ffill", axis=1)
    df = df.replace({'not_observed': np.nan})

    # compute differences
    df.iloc[:, 6:] = df.iloc[:, 5:].diff(axis=1).iloc[:, 1:]

    # some formatting
    value_cols = [c for c in df.columns if 'value' in c]
    for col in value_cols:
        df[col] = df[col].astype('Int64')

    df = df[['location', 'age_group', 'year', 'week', 'date'] + value_cols]

    df = df.sort_values(['location', 'age_group', 'date'], ignore_index=True)

    df.to_csv(f'../data/truth/truth_{disease.lower()}.csv', index=False)


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

DISEASES = ['Seasonal_Influenza', 'RSV_Infection', 'Pneumococcal_Disease']

for disease in DISEASES:
    compute_reporting_triangle(disease)
