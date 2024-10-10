import os
import re
import requests
import pandas as pd
from pathlib import Path
from epiweeks import Week

def get_all_date_tags(owner, repo):
    # Define the GitHub API URL for tags
    tags_url = f"https://api.github.com/repos/{owner}/{repo}/tags"
    
    # Send a GET request to retrieve the list of tags
    response = requests.get(tags_url)
    
    if response.status_code == 200:
        # Parse the JSON response to get the list of tags
        tags_data = response.json()
        
        # Filter tags that match the "yyyy-mm-dd" format
        date_tags = [tag["name"] for tag in tags_data if re.match(r'\d{4}-\d{2}-\d{2}', tag["name"])]
        
        return date_tags
    else:
        # Handle errors, e.g., repository not found or authentication issues
        print(f"Failed to retrieve tags. Status code: {response.status_code}")
        return []

def load_file_from_tag(owner, repo, filepath, tag):
    # Get the commit sha associated with the given tag
    tag_url = f"https://api.github.com/repos/{owner}/{repo}/git/refs/tags/{tag}"
    tag_response = requests.get(tag_url)
    tag_data = tag_response.json()
    sha = tag_data["object"]["sha"]

    # Load the corresponding data in TSV format
    raw_data_url = f"https://raw.githubusercontent.com/{owner}/{repo}/{sha}/{filepath}"
    data = pd.read_csv(raw_data_url, sep='\t')
    
    return data

def previous_sunday(date):
    return str((Week.fromdate(pd.to_datetime(date), system='iso') - 1).enddate())

def preprocess_sari(df):
    df = df.drop(columns=['Saison', 'SARI'], errors='ignore')

    df = df.rename(columns={'Kalenderwoche' : 'date',
                            'Altersgruppe' : 'age_group',
                            'Hospitalisierungsinzidenz' : 'value'})
    
    AGE_GROUPS = {'0-4' : '00-04', 
                  '5-14' : '05-14'}
    
    df.age_group = df.age_group.replace(AGE_GROUPS)

    df.date = df.date.apply(lambda x: Week(int(x[:4]), int(x[6:]), system="iso"))
    df['week'] = df.date.apply(lambda x: x.week)
    df['year'] = df.date.apply(lambda x: x.year)
    df.date = df.date.apply(lambda x: x.enddate())
    
    df['location'] = 'DE'
    
    # convert from incidence (per 100,000) to absolute counts
    population = pd.read_csv('https://raw.githubusercontent.com/KITmetricslab/RESPINOW-Hub/main/respinow_viz/plot_data/other/population_sizes.csv', 
                        usecols=['location', 'age_group', 'population'])
    population = population[population.location == 'DE']
    pop_dict = dict(zip(population.age_group, population.population))
    df.value = df.apply(lambda x: int(x['value']*pop_dict[x['age_group']]/100000), axis=1)
    
    return df[['date', 'year', 'week', 'location', 'age_group', 'value']]

OWNER = "robert-koch-institut"
REPO = "SARI-Hospitalisierungsinzidenz"
FILEPATH = "SARI-Hospitalisierungsinzidenz.tsv"

SARI_DICT = {
    'Gesamt' : 'sari',
    'COVID-19' : 'sari_covid19',
    'Influenza': 'sari_influenza',
    'RSV': 'sari_rsv'
}

tags = get_all_date_tags(OWNER, REPO)
print("List of tags:", tags)

for s in SARI_DICT.values():
    os.makedirs(f'../data/SARI/{s}/', exist_ok=True)

# path = Path('../data/SARI/sari/')
# os.makedirs(path, exist_ok=True)
# dates_processed = sorted([file.name[:10] for file in path.glob('*.csv')])
# new_dates = [date for date in tags if previous_sunday(date) not in dates_processed]
new_dates = [t for t in tags if t >= '2024-10-10']

for date in new_dates:
    print(date)
    df = load_file_from_tag(OWNER, REPO, FILEPATH, date)

    for c in df.SARI.unique():
        print(f' - {c}')
        df_temp = df[df.SARI == c]
        df_temp = preprocess_sari(df_temp)
        df_temp = df_temp.sort_values(['date', 'location', 'age_group'], ignore_index=True)
        df_temp.to_csv(f'../data/SARI/{SARI_DICT[c]}/{previous_sunday(date)}-icosari-{SARI_DICT[c]}.csv', index=False)
    
