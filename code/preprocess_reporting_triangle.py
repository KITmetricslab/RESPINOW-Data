import pandas as pd

for disease in ['seasonal_influenza', 'pneumococcal_disease', 'rsv_infection']:
    df = pd.read_csv(f'../data/Survstat/{disease}_reporting_triangle_survstat.csv')

    for i, row in df.iterrows():
        to_subtract = 0
        for j, value in row[:4:-1].items():
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

    df.sort_values(['location', 'age_group', 'date'], inplace = True)

    df.to_csv(f'../data/Survstat/{disease}_reporting_triangle_survstat_preprocessed.csv', index = False)
