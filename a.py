import requests
import json
import nltk 
from tqdm import tqdm
from nltk.corpus import stopwords 
from nltk.tokenize import word_tokenize, sent_tokenize 
from nltk.stem.wordnet import WordNetLemmatizer


stop_words = set(stopwords.words('english'))
lem = WordNetLemmatizer()

def download_common_words():
    url = 'https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english-usa-no-swears.txt'
    x = requests.get(url).text
    data = []
    for i in x.split('\n'):
        i = i.strip()
        if i in stop_words:
            continue
        data.append(lem.lemmatize(i))
    json.dump(list(set(data)),open("common_words.json","w"))

    
common_words = set(json.loads(open("common_words.json","r").read()))

article = """
U.S. vaccine manufacturer Novavax, said its COVID-19 vaccine had shown an overall efficacy of 90.4%  in trials in the U.S. and Mexico, potentially adding — in a few months — another vaccine to the world’s arsenal against the disease which has killed close to four million people.  Trials have already occurred in the UK and South Africa.

The Maryland-based company, which tested its two dose ‘NVX-CoV2373’ vaccine on a population of just under 30,000 adults in the U.S. and Mexico, said the jabs provided 100% protection against moderate to severe disease and an overall efficacy of 90.4%. Of the 77 individuals out of 29,960 in the trial who contracted COVID-19, 14 received the actual vaccine, doses of which were spaced three weeks apart, while 63 had received placebos.

Ten moderate to severe cases of the disease were observed, but all were confined to the placebo group, the company said. All 14 infections in the vaccinated group were mild.  Preliminary data suggest that the vaccine is safe, according to a press release from Novavax.

Novavax detected strains of the virus found first in the U.K.,U.S., Brazil, South Africa and India, according to data released by the company during a Monday morning conference call. After surviving years of crippling drought, farmers in eastern Australia are locked in a months-long battle with hordes of mice that are pouring through fields and devouring hard-earned crops.

Farmer Col Tink uses a broom to skittle hundreds of roving mice toward a makeshift industrial trap — essentially a large tub of water where they drown.

It is a brutally simple attempt to slow the plague that has engulfed his farm — near the rural town of Dubbo — and thousands of other farms like it across eastern Australia. But Tink's efforts have barely made a dent. Mice continue to chew through grain and hay stocks while anything remotely edible remains under constant attack.

Skin-crawling videos of writhing rodent masses have been shared around the world along with reports of bitten hospital patients, destroyed machinery and swarms running across roads en masse.
"""

        
        
def get_word_difficulty(word):
    # future implementation, cookie can be used 
    url = "https://www.twinword.com/api/score/word/latest/"
    data = {"entry":word}
    headers = {"Host":"www.twinword.com","Referer":"https://www.twinword.com/api/language-scoring.php","User-Agent":"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0"}
    response = requests.post(url,data=data)
    if response.status_code == 200:
        x = json.loads(response.content.decode())
        if x["result_code"] == "462":
            # word not found 
            return 0
        return x["value"]
    else:
        # api failed , we are exposed
        return None


def get_word_features(word):
    url = f"https://www.shabdkosh.com/search-dictionary?lc=hi&sl=en&tl=hi&e={word}"
    headers = {"Referer":"https://www.google.com","User-Agent":"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0"}
    response = requests.get(url, headers = headers)

'''


def get_difficult_words(article):
    filtered_words = []
    tok_sentences = sent_tokenize(article)
    words = []
    for sentence in tqdm(tok_sentences):
        words = word_tokenize(sentence)
        words = nltk.pos_tag(words)
        for j in words:
            word, tag = j
            word = word.lower()
            word = lem.lemmatize(word)

            # removing unwanted characters # % &
            if len(word) == 1:
                continue

            if word in stop_words:
                continue
            if word in common_words:
                continue 
            if word in filtered_words:
                continue
            if tag not in ['NN', 'JJ']:
                continue

            '''
            difficulty = get_word_difficulty(word)
            if difficulty is None:
                # ranking not working due to api failure
                difficulty = 0
            '''
            difficulty =  0
            filtered_words.append(word)

    # ranking words on the basis of difficulty
    difficult_words = sorted(filtered_words,reverse=True)

    return difficult_words 

print(get_difficult_words(article))