import pandas as pd
from pathlib import Path

source_dict = {
    'SARI' : ['sari'],
    'NRZ' : ['influenza', 'rsv'],
    'Survstat' : ['influenza', 'rsv', 'pneumococcal']
}

def combine_file_history(files):
    df = pd.read_csv(files[0])
    for f in files[1:]:
        df_new = pd.read_csv(f)
        df = pd.concat([df_new, df]).drop_duplicates(subset=['date', 'week', 'location', 'age_group'])

    df = df.sort_values(['location', 'age_group', 'date'])
    df.to_csv(f'../data/{source}/latest_data-{source}-{disease}{"-tests" if nrz_type == "AmountTested" else ""}.csv', index=False)

for source in source_dict.keys():
    print(source)
    
    for disease in source_dict[source]:
        path = Path(f'../data/{source}/{disease}/')
        print(path)
        
        if source == 'NRZ':
            for nrz_type in ['VirusDetections', 'AmountTested']:
                files = sorted([f for f in path.rglob('*.csv') if nrz_type in f.name])
                combine_file_history(files)
        else:
            nrz_type = None
            files = sorted([f for f in path.rglob('*.csv')])
            combine_file_history(files)
        