import os
import time
import pandas as pd
from pathlib import Path
from zipfile import ZipFile
from selenium.webdriver import Chrome, ChromeOptions
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager


# Function for merging dfs
def merge_new_data(old_data, new_data):
    # Get duplicate ids
    ids_dup = old_data[["respId", "patId"]].merge(new_data[["respId", "patId"]], how="inner", on=["respId", "patId"])

    # Create duplicate and new values
    duplicate = new_data[(new_data["respId"].isin(ids_dup["respId"])) & (new_data["patId"].isin(ids_dup["patId"]))]
    new = new_data[~((new_data["respId"].isin(ids_dup["respId"])) & (new_data["patId"].isin(ids_dup["patId"])))]

    # Merge dataframes
    merged = old_data[~((old_data["respId"].isin(ids_dup["respId"])) & (old_data["patId"].isin(ids_dup["patId"])))]
    merged = pd.concat([merged, duplicate, new], axis=0)
    return merged


url = 'https://uni-koeln.sciebo.de/s/fwiRFf2Ya9AxbxG'
password = os.environ['RESPVIR'] # How do we specify the password on the server?

path_loc = os.path.join(os.getcwd(), "temp")

options = ChromeOptions()
chrome_prefs = {
    "download.prompt_for_download": False,
    "plugins.always_open_pdf_externally": True,
    "download.open_pdf_in_system_reader": False,
    "profile.default_content_settings.popups": 0,
    "download.default_directory": path_loc
}
options.add_experimental_option("prefs", chrome_prefs)
options.add_argument("--headless")
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
options.add_argument('--disable-gpu')

driver = Chrome(service=Service(ChromeDriverManager().install()), options=options)
driver.get(url)

time.sleep(10)
password_field = driver.find_element("name", "password")
password_field.send_keys(password)
password_field.submit()
time.sleep(10)

# check available dates
files = driver.find_element("id", "fileList")
dates_available = [f[-14:-4] for f in files.text.replace("\n", " ").split(" ") if
                   f.startswith('filtered') and f.endswith('.zip')]
# Get base file and new files
base_index = 1
base_date = dates_available[base_index]
new_dates = dates_available[base_index:]


# Check if newest file is already processed
dir_URL = Path("../data/RespVir/influenza/")
dates_processed = [file.name[:10] for file in dir_URL.glob("*.csv")]
dates = [d for d in new_dates if d not in dates_processed]

if (dates_processed[-1] == new_dates[-1]):
    print("Repository already up to date!")
else:
    # Download all files
    for d in dates:
        # download file
        print(f"Downloading file: filtered_{d}.zip")
        file_url = f'https://uni-koeln.sciebo.de/s/fwiRFf2Ya9AxbxG/download?path=%2F&files=filtered_{d}.zip'
        driver.get(file_url)
        # Wait for file to materialize
        time.sleep(5)
        # unzip and rename file
        zipdata = ZipFile(f"temp/filtered_{d}.zip")
        for z in zipdata.infolist():
            z.filename = f"respAll_filtered_{d}.csv"
            zipdata.extract(z, path="temp", pwd=bytes(password, 'utf-8'))

    # Create merged files
    path = "temp/respAll_filtered_{}.csv"
    base_df = pd.read_csv(path.format(base_date))
    # Filter data on relevant columns
    cols = ["respId", "patId", "dt", "date", "infasaisonpos", "rsvpos", "bakstrepos"]
    merged_df = base_df[cols]

    for date in dates:
        new_file = "temp/respAll_filtered_{}.csv".format(date)
        new_df = pd.read_csv(new_file)
        # Filter data on newest change date
        new_df = new_df[new_df["dt"] >= base_date]
        new_df = new_df[cols]
        merged_df = merge_new_data(merged_df, new_df)
        merged_df.to_csv("temp/{}_aggregated.csv".format(date), index=False)
