import os
import numpy as np
import pandas as pd
import requests
from epiweeks import Week
from tqdm.auto import tqdm

def load_data(disease, date):
    try:
        df = pd.read_csv(f"../data/NRZ/{disease}/{date}_VirusDetections.csv")
        df.date = pd.to_datetime(df.date)
        df.date = df.date.apply(lambda x: Week.fromdate(x, system='iso').enddate())
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

def list_all_files(disease):
    # load all files from repo
    PATH = '../data/NRZ/'
    # diseases = os.listdir(PATH)

    files = os.listdir(PATH + disease)

    files = [f for f in files if 'VirusDetections' in f]
    print(files[-5:])

    # create dataframe so we can easily select files by date
    df_files = pd.DataFrame({'filename': files})

    # extract date from filename
    df_files['date'] = df_files.filename.str[0:10]
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
                     states=['DE', 'DE-BW', 'DE-BY', 'DE-BB-BE', 'DE-HE', 'DE-MV', 'DE-NI-HB',
       'DE-NW', 'DE-RP-SL', 'DE-SN', 'DE-ST', 'DE-SH-HH', 'DE-TH'],
                     age_groups=['00+', '00-04', '05-14', '15-34', '35-59', '60-79', '80+']):

    df_states = pd.DataFrame({'date': date.enddate(),
                              'year': date.year,
                              'week': date.week,
                              'location': states,
                              'age_group': '00+',
                              'value': np.nan})

    return df_states

def make_template(dates):
    states=['DE', 'DE-BW', 'DE-BY', 'DE-BB-BE', 'DE-HE', 'DE-MV', 'DE-NI-HB',
       'DE-NW', 'DE-RP-SL', 'DE-SN', 'DE-ST', 'DE-SH-HH', 'DE-TH']

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

    df = make_template(dates)
    for delay in tqdm(range(0, max_delay + 1), total=max_delay + 1, desc=f"{disease.replace('_', ' ')}: "):
        relevant_dates = [d for d in dates if d <= max(dates) - delay]
        print(relevant_dates[-10:])
        df_temp = make_template(relevant_dates)
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

    df.to_csv(f'../data/NRZ/{disease}_reporting_triangle.csv', index=False)

DISEASES = ['influenza', 'rsv']

for disease in DISEASES:
    compute_reporting_triangle(disease)
