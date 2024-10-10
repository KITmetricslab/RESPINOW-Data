import pandas as pd
from pathlib import Path

def preprocess_reporting_triangle(df):
    for i, row in df.iterrows():
        to_subtract = 0
        for j, value in row[:4:-1].items():
            if pd.notna(value):
                value += to_subtract
                if value < 0:
                    to_subtract = value
                    df.loc[i, j] = 0
                else:
                    df.loc[i, j] = value
                    to_subtract = 0

    value_cols = [c for c in df.columns if 'value' in c]
    for col in value_cols:
        df[col] = df[col].astype('Int64')
    
    return(df)


path = Path('../data/')
files = [f for f in path.rglob('*reporting_triangle*.csv') if 'preprocessed' not in f.name]

for f in files:
    print("Processing:", f)
    df = pd.read_csv(f)
    df = df.loc[:, : 'value_4w']
    if 'are' not in f.name:
        df = preprocess_reporting_triangle(df)
    df = df.sort_values(['location', 'age_group', 'date'])
    df.to_csv(f.with_name(f.stem + "-preprocessed.csv"), index = False)
    print("Done:", f.with_name(f.stem + "-preprocessed.csv\n"))
    
