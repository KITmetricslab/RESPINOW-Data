import pandas as pd
from pathlib import Path

SOURCE_DICT = {
    'SARI' : ['sari'],
    'NRZ' : ['influenza', 'rsv'],
    'Survstat' : ['influenza', 'rsv', 'pneumococcal'],
    'CVN' : ['influenza', 'rsv', 'pneumococcal'],
    'AGI' : ['are']
}

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

def combine_file_history(files):
    files = sorted(files)
    df = pd.read_csv(files[0])
    
    for f in files[1:]:
        df_new = pd.read_csv(f)
        df = pd.concat([df_new, df]).drop_duplicates(subset=['date', 'week', 'location', 'age_group'])
        
    return df

def compute_latest_data(source, disease, tests=False):
    path = Path(f'../data/{source}/{disease}/')
    files = [f for f in path.glob('*.csv') if ('test' in f.name.lower()) == tests]
    
    df = combine_file_history(files)
    
    if source in ['Survstat', 'AGI']:
        df.location = df.location.replace(STATE_DICT)
        df = df.groupby(['date', 'year', 'week', 'location', 'age_group']).sum().reset_index()
        
    df = df.sort_values(['location', 'age_group', 'date'])
    df.to_csv(f'../data/{source}/latest_data-{source}-{disease}{"-tests" if tests else ""}.csv', index=False)

    
for source in SOURCE_DICT.keys():
    print('___________')
    print(source)
    
    for disease in SOURCE_DICT[source]:
        if source in ['NRZ', 'CVN']:
            compute_latest_data(source, disease)
            compute_latest_data(source, disease, tests=True)
        else:
            compute_latest_data(source, disease)
