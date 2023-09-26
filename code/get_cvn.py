import os
import pandas as pd
from pathlib import Path
import requests
from pyzipper import AESZipFile
from io import BytesIO
from epiweeks import Week

USERNAME = os.environ['CVN_USER']
PASSWORD = os.environ['CVN_PASSWORD']
URL = os.environ['CVN_URL']

def process_files(files):
    cols = ['respId', 'patId', 'dt', 'date', 'infasaisonpos', 'rsvpos', 'bakstrepos']

    dfs = []
    for file in files:
        r = requests.get(URL + file, auth=(USERNAME, PASSWORD))
        
        if r.status_code == 200:
            zipdata = AESZipFile(BytesIO(r.content)) # unzip without writing to file
            temp = pd.read_csv(zipdata.open('respAll_filtered.csv', pwd=bytes(PASSWORD,'utf-8')), 
                               usecols=lambda x: x in cols, encoding='unicode_escape')
#             if len(temp.columns) != len(cols):
#                 print(f"Missing columns in {file}: {[c for c in cols if c not in temp.columns]}.")
            dfs.append(temp)     
        else:
            print(f"{file} does not exist.")
    df = pd.concat(dfs)        
    
    df = df.dropna() # drop data from 2023-04-05, add again afterwards?
    df = df.drop_duplicates(['respId', 'patId', 'date'], keep='last')

    df = df.melt(id_vars=['date'], value_vars=['infasaisonpos', 'rsvpos', 'bakstrepos'], var_name = 'disease')

    df.disease = df.disease.replace({'bakstrepos': 'pneumococcal', 
                                       'infasaisonpos': 'influenza', 
                                       'rsvpos': 'rsv'})

    df = df[df.value != 3].copy() # remove untested
    df.value = (df.value == 2) # True = positive test

    df = df.groupby(['disease', 'date']).value.agg(value = 'sum', tests = 'count').reset_index()
    
    df['location'] = 'DE'
    df['age_group'] = '00+'
    
    df = df.sort_values(['location', 'age_group', 'date'], ignore_index=True)
    df = df[['disease', 'date', 'location', 'age_group', 'value', 'tests']]
    
    return(df)

def export_cvn(df, date, tests=False):
    for disease in df.disease.unique():
        # daily resolution
        path = f'../data/CVN/daily_resolution/{disease}/'
        os.makedirs(path, exist_ok=True)
        filename = f'{date}-cvn-{disease}{"-tests" if tests else ""}.csv'
        print(filename)
        temp = df[df.disease == disease].copy()
        if not tests:
            temp = temp.drop(columns=['disease', 'tests'])
        else:
            temp = temp.drop(columns=['disease', 'value']).rename(columns={'tests' : 'value'})
        temp.to_csv(path + filename, index=False)

        # 7-day incidence
        path = f'../data/CVN/{disease}/'
        os.makedirs(path, exist_ok=True)  
        data_version = Week.fromdate(pd.to_datetime(date), system='iso').enddate()
        filename = f'{data_version}-cvn-{disease}{"-tests" if tests else ""}.csv'
        print(filename)

        temp.date = pd.to_datetime(temp.date)
        temp = temp.groupby([pd.Grouper(key='date', freq='1W'), 'location', 'age_group']).sum().reset_index()
        temp['week'] = temp.date.apply(lambda x: Week.fromdate(x, system='iso').week)
        temp['year'] = temp.date.apply(lambda x: Week.fromdate(x, system='iso').year)
        temp = temp[['date', 'year', 'week', 'location', 'age_group', 'value']]
        temp.to_csv(path + filename, index=False)


path = Path('../data/CVN/daily_resolution/influenza/')
dates_processed = sorted([file.name[:10] for file in path.glob('*.csv')])
dates_processed = []
if len(dates_processed) == 0: dates_processed = ['2022-09-20']

possible_dates = pd.date_range(pd.to_datetime(dates_processed[-1]), pd.Timestamp.today(), 
                               inclusive='right').strftime("%Y-%m-%d").to_list()

new_dates = []
for date in possible_dates:
    r = requests.head(URL + f'filtered_{date}.zip', auth=(USERNAME, PASSWORD))
    if r.status_code == 200:
        new_dates.append(date)
        
if (len(new_dates) == 0):
    print("Repository already up to date!")
else:
    for date in new_dates:
        print(date)
        dates_processed.append(date)
        files = [f'filtered_{date}.zip' for date in dates_processed]
        df = process_files(files)
        export_cvn(df, date, tests=False)
        export_cvn(df, date, tests=True)
            
