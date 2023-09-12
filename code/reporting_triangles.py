import os
import numpy as np
import pandas as pd
from epiweeks import Week
from tqdm.auto import tqdm


STATE_DICT = {
    'DE-BB' : 'DE-BB-BE', 
    'DE-BE' : 'DE-BB-BE',
    'DE-NI' : 'DE-NI-HB',
    'DE-HB' : 'DE-NI-HB',
    'DE-RP' : 'DE-RP-SL',
    'DE-SL' : 'DE-RP-SL',
    'DE-SH' : 'DE-SH-HH',
    'DE-HH' : 'DE-SH-HH'
}


def load_data(source, disease, date, nrz_type='VirusDetections'):
    if source == 'NRZ':
        path = f'../data/NRZ/{disease}/{date}_{nrz_type}.csv'
    elif source == 'SARI':
        path = f'../data/SARI/sari/{date}-icosari-sari.csv'
    elif source == 'Survstat':
        path = f'../data/Survstat/{disease}/{date}-survstat-{disease}.csv'
    
    try:
        df = pd.read_csv(path)
        df.date = pd.to_datetime(df.date)
        df.date = df.date.apply(lambda x: Week.fromdate(x, system='iso').enddate())
        
        if source == 'Survstat':
            df.location = df.location.replace(STATE_DICT)
            df = df.groupby(['date', 'year', 'week', 'location', 'age_group']).sum().reset_index()
        
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


def list_all_files(source, disease, nrz_type='VirusDetections'):
    # load all files from repo
    files = os.listdir(f'../data/{source}/{disease}')
     
    # create dataframe so we can easily select files by date
    df_files = pd.DataFrame({'filename': files})

    # extract date from filename
    df_files['date'] = df_files.filename.str[0:10]
        
    df_files.date = pd.to_datetime(df_files.date)
    df_files = add_iso_dates(df_files)
    
    if source == 'NRZ':
        df_files = df_files[df_files.filename.str.contains(nrz_type)]
        df_files = df_files[df_files.date >= "2022-07-24"]
    
    return df_files


def get_date_range(df_files):
    max_date = df_files.iso_date.max().enddate()
    min_date = df_files.iso_date.min().enddate()

    dates = pd.date_range(min_date, max_date, freq="1W")
    dates = [Week.fromdate(d, system='iso') for d in dates]

    return dates


def make_placeholder(date,
                     states=['DE-BB-BE', 'DE-BW', 'DE-BY', 'DE-HE', 'DE-MV', 'DE-NI-HB',
                             'DE-NW', 'DE-RP-SL', 'DE-SH-HH', 'DE-SN', 'DE-ST', 'DE-TH'],
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


def make_template(source, disease, dates):
    states=['DE-BB-BE', 'DE-BW', 'DE-BY', 'DE-HE', 'DE-MV', 'DE-NI-HB',
            'DE-NW', 'DE-RP-SL', 'DE-SH-HH', 'DE-SN', 'DE-ST', 'DE-TH']
    age_groups=['00+', '00-04', '05-14', '15-34', '35-59', '60-79', '80+']

    if source == 'NRZ':
        age_groups = ['00+']
    elif source == 'SARI':
        states = []
    elif source == 'Survstat' and disease == 'rsv':
        states = ['DE-SN']

    dfs = []
    for date in dates:
        df = make_placeholder(date, states, age_groups)
        dfs.append(df)
    df = pd.concat(dfs, ignore_index=True)
    df = df.drop(columns=['value'])

    return df


def load_delayed_data(source, disease, date, data_version, nrz_type='VirusDetections'):
    try:
        df = load_data(source, disease, data_version.enddate(), nrz_type)
    except:
        df = None

    # select relevant rows if df_temp is not None
    if df is not None:
        df = df[(df.date == date.enddate())]

    return df


def load_latest_data(source, disease, nrz_type='VirusDetections'):
    df = pd.read_csv(f'../data/{source}/latest_data-{source}-{disease}{"-tests" if nrz_type == "AmountTested" else ""}.csv')
    df.date = pd.to_datetime(df.date)
    df.date = df.date.apply(lambda x: Week.fromdate(x, system='iso').enddate())
    return(df)


def compute_reporting_triangle(source, disease, nrz_type='VirusDetections', max_delay=10):

    df_files = list_all_files(source, disease, nrz_type)
    dates = get_date_range(df_files)

    df = make_template(source, disease, dates)
    for delay in tqdm(range(0, max_delay + 1), total=max_delay + 1, desc=f'{disease}{"-tests" if nrz_type == "AmountTested" else ""}: '):
        relevant_dates = [d for d in dates if d <= max(dates) - delay]
        df_temp = make_template(source, disease, relevant_dates)
        dfs = []
        for date in relevant_dates:
            data_version = date + delay
            df_delayed = load_delayed_data(source, disease, date, data_version, nrz_type)
            dfs.append(df_delayed)
        df_delayed = pd.concat(dfs)
        df_temp = df_temp.merge(df_delayed, how='left')

        # we flag missing values to fill later on (not all should be filled to preserve reporting triangle shape)
        df_temp.value = df_temp.value.fillna('to_fill')

        df_temp = df_temp.rename(columns={'value': f'value_{delay}w'})

        df = df.merge(df_temp, how='left')

    # use latest file to compute column for remaining correction beyond the specified largest delay
    df_latest = load_latest_data(source, disease, nrz_type)
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
    
    path = (f'../data/{source}/reporting_triangle-{"icosari" if source == "SARI" else source.lower()}'
            f'-{disease}{"-tests" if nrz_type == "AmountTested" else ""}.csv')
    
    df.to_csv(path, index=False)


# Compute all reporting triangles

SOURCE_DICT = {
    'SARI' : ['sari'],
    'NRZ' : ['influenza', 'rsv'],
    'Survstat' : ['influenza', 'rsv', 'pneumococcal']
}

for source in SOURCE_DICT.keys():
    print('___________')
    print(source)
    
    for disease in SOURCE_DICT[source]:
        if source == 'NRZ':
            compute_reporting_triangle(source, disease, 'VirusDetections')
            compute_reporting_triangle(source, disease, 'AmountTested')
        else:
            compute_reporting_triangle(source, disease)
