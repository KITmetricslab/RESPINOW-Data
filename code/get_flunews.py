import os
import time
import pandas as pd
from datetime import datetime
from selenium.webdriver import Chrome, ChromeOptions
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from webdriver_manager.chrome import ChromeDriverManager

#Specify path to FluNews folder
folder_path = "../data/FluNewsEurope/"

#Get current date and output filename
iso_date = datetime.now().isocalendar()
file_name = f"SARI-{iso_date[0]}-{iso_date[1]}.csv"
file_path = folder_path + file_name

#Website URL
url = 'https://flunewseurope.org/HospitalData/SARI'

#Define available seasons - most recent is already selected
seasons = ["2021/2022", "2020/2021"]

#Configure selenium
options = ChromeOptions()
chrome_prefs = {
    "download.prompt_for_download": False,
    "plugins.always_open_pdf_externally": True,
    "download.open_pdf_in_system_reader": False,
    "profile.default_content_settings.popups": 0,
    "download.default_directory": folder_path
}
options.add_experimental_option("prefs", chrome_prefs)
options.add_argument('--window-size=1920,1080')
options.add_argument("--headless")
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
options.add_argument('--disable-gpu')

driver = Chrome(service=Service(ChromeDriverManager().install()), options=options)
driver.get(url)
wait = WebDriverWait(driver, 10)
#Wait for website to load
time.sleep(7)

# Select country
country_selector = driver.find_element_by_xpath("/html/body/div[2]/div/div[3]/div[5]/div[1]/div/article/div[1]/div/div/qv-filterpane/div[3]/div/div")
country_selector.click()
entry_path = "/html/body/div[5]/div/div/div/ng-transclude/div/div[3]/div/article/div[1]/div/div/div/div[1]/div/input"
country_query = "Germany"+Keys.ENTER
wait.until(EC.presence_of_element_located((By.XPATH, entry_path))).send_keys(country_query)
time.sleep(1)

#Select season
season_selector = driver.find_element_by_xpath("/html/body/div[2]/div/div[3]/div[5]/div[1]/div/article/div[1]/div/div/qv-filterpane/div[1]/div/div")
season_selector.click()
entry_path = "/html/body/div[5]/div/div/div/ng-transclude/div/div[3]/div/article/div[1]/div/div/div/div[1]/div/input"
season_entry = wait.until(EC.presence_of_element_located((By.XPATH, entry_path)))
for season in seasons:
    season_entry.send_keys(season+Keys.ENTER)
    time.sleep(1)

#Download file
download_button = driver.find_element_by_xpath("//*[@id=\"export_chart_1_csv\"]")
download_button.send_keys(Keys.ENTER)
time.sleep(3)

#Load csv file
csv_file = list(filter(lambda f: f.endswith("xlsx"),os.listdir(folder_path)))[0]
csv_path = folder_path + csv_file

data = pd.read_excel(csv_path)
data = data.loc[data["Country"] == "Germany"]
data["location"] = "DE"
data = data.drop(["Season","% positive COVID-19", "% positive influenza", "Region", "Country"], axis = 1)

#Add columns
data["date"] = data["Week"].apply(lambda x : datetime.strptime(x + '-0', "%Y-W%W-%w"))
data["Week"] = data["Week"].apply(lambda x: x[-2:])
data["age_group"] = "00+"

#Rename columns
data.rename(columns = {"Week" : "week",
                      "Number of SARI cases" : "value"},
            inplace = True)

#Sort columns
data = data[["date", "week", "location", "age_group", "value"]]

#Export csv file
data.to_csv(file_path, index = False)

#Remove previous file
os.remove(csv_path)
