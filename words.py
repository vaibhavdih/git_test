from nltk.stem.wordnet import WordNetLemmatizer


#stop_words = set(stopwords.words('english'))
lem = WordNetLemmatizer()

class words():
    def __init__(self):
        self.a = lem.lemmatize("gone")
        print(self.a)


x = words()