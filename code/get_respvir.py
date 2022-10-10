import os
import pandas as pd
from pathlib import Path
from zipfile import ZipFile
from selenium.webdriver import Chrome, ChromeOptions
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

def get_previous_sunday(date):
    return str((pd.to_datetime(date) - pd.Timedelta(days=((pd.to_datetime(date).dayofweek + 1) % 7))).date())

url = 'https://uni-koeln.sciebo.de/s/fwiRFf2Ya9AxbxG'
password = os.environ['RESPVIR']

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

password_field = driver.find_element("name", "password")
password_field.send_keys(password)
password_field.submit()

# check available dates
files = driver.find_element("id", "fileList")
dates_available = [f[-14:-4] for f in files.text.replace("\n", " ").split(" ") if f.startswith('filtered') and f.endswith('.zip')]
sundays = [get_previous_sunday(d) for d in dates_available]
date_dict = dict(zip(sundays, dates_available))

# check which dates have already been downloaded/processed
dir_URL = Path("../data/RespVir/influenza/")
dates_processed = [file.name[:10] for file in dir_URL.glob("*.csv")]

dates = [d for d in date_dict.keys() if d not in dates_processed]
print(dates_available)
print(sundays)
print(dates_processed)
print(dates)

for d in dates:
    # download file
    print(f"Downloading file: filtered_{date_dict[d]}.zip")
    file_url = f'https://uni-koeln.sciebo.de/s/fwiRFf2Ya9AxbxG/download?path=%2F&files=filtered_{date_dict[d]}.zip'
    driver.get(file_url)
    
    # unzip and rename file
    zipdata = ZipFile(f"temp/filtered_{date_dict[d]}.zip")
    for z in zipdata.infolist():
        z.filename = f"respAll_filtered_{date_dict[d]}.csv"
        zipdata.extract(z, path = "temp", pwd=bytes(password,'utf-8'))
