import os
import pandas as pd
from epiweeks import Week

files = os.listdir('../data/SARI/archive/')
df_files = pd.DataFrame({'filename': files})

# extract date from filename
df_files['file_date'] = df_files.filename.str[5:12]
df_files['date'] = df_files.file_date.str.replace('-', 'W')
df_files.date = df_files.apply(lambda x: Week.fromstring(x.date, system='iso').enddate(), axis=1)
df_files.date = pd.to_datetime(df_files.date)

# to fix typos in sari files
age_dict = {
    '+00' : '00+',
    '+80' : '80+'
}

for i, row in df_files.iterrows():
    df = pd.read_csv(f'../data/SARI/archive/{row.filename}')
    df.age_group = df.age_group.replace(age_dict) # fix typos
    df.to_csv(f'../data/SARI/sari/{row.date.date()}-icosari-sari.csv', index = False)