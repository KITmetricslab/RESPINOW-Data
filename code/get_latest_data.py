import pandas as pd
from pathlib import Path

source_dict = {
    'SARI' : ['archive'],
    'NRZ' : ['influenza', 'rsv']
}

# to fix typos in sari files
age_dict = {
    '+00' : '00+',
    '+80' : '80+'
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
            
        df = pd.read_csv(files[0])
        
        # we concat the new and the current file and then drop duplicate entries (keeping the one from the new file)
        for f in files[1:]:
            df_new = pd.read_csv(f)
            df_new.age_group = df_new.age_group.replace(age_dict) # fix typos
            df = pd.concat([df_new, df]).drop_duplicates(subset=['date', 'week', 'location', 'age_group'])
        
        df = df.sort_values(['location', 'age_group', 'date'])

        df.to_csv(f'../data/{source}/latest_data-{source}-{folder}.csv', index=False)
        