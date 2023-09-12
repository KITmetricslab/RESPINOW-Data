import pandas as pd
from pathlib import Path

source_dict = {
    'SARI' : ['sari'],
    'NRZ' : ['influenza', 'rsv'],
    'Survstat' : ['influenza', 'rsv', 'pneumococcal']
}

for source in source_dict.keys():
    print(source)
    
    for folder in source_dict[source]:
        path = Path(f'../data/{source}/{folder}/')
        print(path)
        
        if source == 'SARI':
            files = sorted([f for f in path.rglob('*.csv') if 'test' not in f.name])
        elif source == 'NRZ':
            files = sorted([f for f in path.rglob('*.csv') if 'VirusDetections' in f.name])
        elif source == 'Survstat':
            files = sorted([f for f in path.rglob('*.csv')])
            
        df = pd.read_csv(files[0])

        for f in files[1:]:
            df_new = pd.read_csv(f)
            df = pd.concat([df_new, df]).drop_duplicates(subset=['date', 'week', 'location', 'age_group'])
        
        df = df.sort_values(['location', 'age_group', 'date'])

        df.to_csv(f'../data/{source}/latest_data-{source}-{folder}.csv', index=False)
        