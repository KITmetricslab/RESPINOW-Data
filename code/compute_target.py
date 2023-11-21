import pandas as pd
from pathlib import Path

def compute_target(df, max_delay=4):
    df = df.loc[:, :f'value_{max_delay}w']
    df['value'] = df[[c for c in df.columns if 'value' in c]].sum(axis=1).astype(int)
    df = df[[c for c in df.columns if 'value_' not in c]]
    return df


path = Path('../data/')
files = [f for f in path.rglob('reporting_triangle*.csv') if 'preprocessed' not in f.name]

for f in files:
    print("Processing:", f)
    df = pd.read_csv(f)
    df = compute_target(df, max_delay=4)
    target_path = f.with_name('target-' + f.name.split('-', 1)[-1])
    df.to_csv(target_path, index=False)
    print("Done:", target_path)
    