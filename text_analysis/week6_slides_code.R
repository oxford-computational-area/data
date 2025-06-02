# Code from slides on text analysis

install.packages(c(
  "ggcorrplot",
  "quanteda",
  "quanteda.textplots",
  "quanteda.textstats",
  "stm",
  "stminsights"
))

devtools::install_github("bstewart/stm", dependencies = TRUE)

devtools::install_github("quanteda/quanteda.sentiment")

# download --------------------

url <- "https://www.kaggle.com/api/v1/datasets/download/unitednations/un-general-debates"
download.file(url, "un-general-debates.zip", mode = "wb")
unzip("un-general-debates.zip")
file.remove("un-general-debates.zip")

# inspect --------------------

library(tidyverse)

df <- read_csv("un-general-debates.csv")

nrow(df)
names(df)
View(head(df))
View(df$text[1])
min(df$year) # 1970
max(df$year) # 2015
length(unique(df$country)) # 199

# extract mena --------------------

# get vector from LLM
mena <- c(
  "DZA", "BHR", "EGY", "IRQ", "JOR", "KWT", "LBN",
  "LBY", "MAR", "OMN", "PSE", "QAT", "SAU", "SYR", "TUN", "ARE",
  "YEM", "ISR", "IRN", "SDN"
)

df_mena <- df |>
  filter(country %in% mena)

nrow(df_mena)

# check that all countries are there
length(mena) == length(unique(df_mena$country))

# see how many entries per country
table(df_mena$country)

# explore text length --------------------

library(tokenizers)

# create word count column
df_mena$n_words <- count_words(df_mena$text)
mean(df_mena$n_words) # ~ 3100
sum(df_mena$n_words) # ~ 2.7M
hist(df_mena$n_words)

# verbosity over time
df_mena |>
  group_by(year) |>
  summarize(avg_count = mean(n_words)) |>
  ggplot() +
  aes(year, avg_count) +
  geom_line()

# verbosity by country
df_mena |>
  group_by(country) |>
  summarize(avg_count = mean(n_words)) |>
  ggplot() +
  aes(reorder(country, avg_count), avg_count) +
  geom_bar(stat = "identity") +
  coord_flip()

# load into quanteda --------------------

library(quanteda)
library(quanteda.textplots)
library(quanteda.textstats)

# create corpus
corp <- corpus(df_mena, text_field = "text")

# make docnames more meaningful
docnames(corp) <- str_glue("{df_mena$country}_{df_mena$year}")

# preprocess --------------------

# Create a stopwords vector
stopwords <- stopwords()
# Add whatever you want
# stopwords <- c(stopwords, "your", "words")

# Tokenize
tok <- corp |>
  tokens(
    remove_punct = TRUE,
    remove_symbols = TRUE,
    remove_numbers = TRUE,
    remove_separators = TRUE,
    split_hyphens = TRUE
  ) |>
  tokens_tolower() |>
  tokens_remove(stopwords)

# Create DFM
dfm_un <- dfm(tok)

# Most common words --------------------

# get top 20 words
topfeatures(dfm_un, 20)

# make wordcloud
textplot_wordcloud(
  dfm_un,
  max_words = 100,
  color = c("orange", "green4", "darkblue", "red")
)

# barplot usually better
df_20 <- textstat_frequency(
  dfm_un,
  n = 20
)

ggplot(df_20) +
  aes(
    reorder(feature, frequency), frequency
  ) +
  geom_bar(stat = "identity") +
  coord_flip()

# Most common words by country --------------------

# Create dataframe with groups variable
df_country <- textstat_frequency(
  dfm_un,
  n = 20,
  groups = dfm_un$country
)

ggplot(df_country, aes(nrow(df_country):1, frequency)) +
  geom_point() +
  scale_x_continuous(
    breaks = nrow(df_country):1,
    labels = df_country$feature
  ) +
  labs(x = "", y = "") +
  coord_flip() +
  facet_wrap(~group, scales = "free", ncol = 5) +
  theme(axis.text.x = element_text(size = 4))

# Most distinctive words by country -----------------------

dfm_un |>
  dfm_group(groups = country) |>
  textstat_keyness(target = "LBY") |>
  textplot_keyness(
    show_reference = FALSE,
    color = "green3"
  )

dfm_un |>
  dfm_group(groups = country) |>
  textstat_keyness(target = "ISR") |>
  textplot_keyness(
    show_reference = FALSE,
    color = "lightblue"
  )

# Lexical diversity over time -----------------------

dfm_year <- dfm_group(dfm_un, groups = year)

df_lexdiv <- textstat_lexdiv(dfm_year, groups = year)

df_lexdiv$year <- as.integer(df_lexdiv$document)

ggplot(df_lexdiv) +
  aes(year, TTR) +
  geom_line()

# document similarity -----------------------

library(ggcorrplot)

dfm_2015 <- dfm_un |>
  dfm_subset(year == 2015)

sim <- textstat_simil(
  dfm_2015,
  method = "cosine",
  margin = "document"
) |>
  as.matrix()

ggcorrplot(sim, type = "upper")

# simple search ----------------------------

# grep returns indices of elements with the search term
grep("London", df_mena$text)

# Add `value = TRUE` to get the actual element
grep("London", df_mena$text, value = TRUE)

# concordances ----------------------------

# we want tokenization but not cleaning
tok_raw <- tokens(corp)

hits <- kwic(tok_raw, pattern = "oil", window = 4)

nrow(hits)
head(hits)


# NER ----------------------------

# run in terminal:
# pip install spacy
# python -m spacy download en_core_web_sm

# NB this is Python code:
import spacy
nlp = spacy.load("en_core_web_sm")

text = "Saddam Hussain attacked Iran in 1980"
doc = nlp(text)

for ent in doc.ents:
  print(ent.text, ent.label_)

# run in terminal:
# pip install pandas

import spacy
import pandas as pd

# load csv
df = pd.read_csv("un-general-debates.csv")

# turn "text" column into list
texts = df['text'].to_list()

# Take just the first ten texts, for speed
texts = texts[0:10]

# Extract 
placenames = []
for text in texts:
  doc = nlp(text)
  for entity in doc.ents:
    if entity.label_ == "GPE":
      placenames.append(entity.text)

# Write to file
with open("places.txt", 'w') as file:
  for place in placenames:
    file.write(f"{place}\n")

# dictionary counts -----------------------

oil <- c("oil", "gas", "petroleum", "barrel", "opec")
dict <- dictionary(list(oil = oil))

# new dfm with proportions
dfm_prop <- dfm_un |>
  dfm_group(groups = year) |>
  dfm_weight(scheme = "prop")

# get dictionary words
dfm_dict <- dfm_prop |>
  dfm_lookup(dictionary = dict)

# convert to dataframe
df_dict <- convert(dfm_dict, to = "data.frame") |>
  rename(year = doc_id, freq = oil) |>
  mutate(year = as.integer(year))
class(df_dict)
str(df_dict)

# draw up
ggplot(df_dict) +
  aes(year, freq) +
  geom_line()

# topic modelling

# Preprocess
dfm_stem <- tok |>
  tokens_wordstem(language = "eng") |>
  dfm() |>
  dfm_trim(
    min_docfreq = 0.1,
    max_docfreq = 0.65,
    docfreq_type = "prop"
  )

# Convert to stm-compatible object
stm_un <- convert(dfm_stem, to = "stm")

# diagnostics
library(stm)
K <- c(5, 10, 15, 20, 25, 30, 35)
kresult <- searchK(
  documents = stm_un$documents,
  vocab = stm_un$vocab,
  K,
  prevalence = ~ s(year),
  data = stm_un$meta,
  cores = 6
)

saveRDS(kresult, "un_kresult.Rdata")
kresult <- readRDS("un_kresult.Rdata")

plot(kresult)


# try k = 10

# train model
m10 <- stm(
  documents = stm_un$documents,
  vocab = stm_un$vocab,
  K = 10,
  prevalence = ~ s(year),
  data = stm_un$meta
)

# save it
saveRDS(m10, "m10.rds")
# m10 <- readRDS("m10.rds")

# view summary
plot(m10, type = "summary")

labelTopics(m10)

# frex only
labels <- labelTopics(m10)
frex <- labels$frex

for (i in 1:10) {
  terms <- str_c(frex[i, ], collapse = ", ")
  line <- str_glue("FREX {i}: {terms}")
  print(line)
}

# try k = 30
m30 <- stm(
  documents = stm_un$documents,
  vocab = stm_un$vocab,
  K = 30,
  prevalence = ~ s(year),
  data = stm_un$meta
)

# save it
saveRDS(m30, "m30.rds")

plot(m30, type = "summary")

# frex
labels <- labelTopics(m30)
frex <- labels$frex
for (i in 1:30) {
  terms <- str_c(frex[i, ], collapse = ", ")
  line <- str_glue("FREX {i}: {terms}")
  print(line)
}

# example doc 1
sample <- findThoughts(
  m30,
  texts = df$text,
  n = 1,
  topics = c(11, 20)
)

# First 3000 chars of topic 11 sample
str_sub(sample$docs[1], 1, 3000)

# Who said it?
index1 <- sample$index[[1]]
docnames(corp)[index1] # Libya 1973

# example doc 1
# First 3000 chars of topic 20 sample
str_sub(sample$docs[2], 1, 3000)

# Oil is buried further down
str_sub(sample$docs[2], 9000, 12000)

# Who said it?
index1 <- sample$index[[2]]
docnames(corp)[index1] # Kuwait 1974

# Over time

library(stminsights)

effects_year <- estimateEffect(~ s(year), m30, meta = stm_un$meta)
df_effects_year <- get_effects(effects_year, "year", type = "pointestimate")

View(df_effects_year)

# oil over time
df_effects_year |>
  filter(topic == 20) |>
  # need to remove factors in "value" variable
  mutate(year = as.integer(as.character(value))) |>
  ggplot() +
  aes(year, proportion) +
  geom_line()

# by country
effects_country <- estimateEffect(~country, m30, meta = stm_un$meta)
df_effects_country <- get_effects(effects_country, "country", type = "pointestimate")
View(df_effects_country)

str(df_effects_country)

# oil by country
df_effects_country |>
  filter(topic == 20) |>
  mutate(country = as.character(value)) |>
  ggplot() +
  aes(reorder(country, proportion), proportion) +
  geom_bar(stat = "identity") +
  coord_flip()

# sentiment ----------------

library(quanteda.sentiment)

dict <- data_dictionary_LSD2015

polarity(dict) <- list(
  pos = "positive",
  neg = "negative"
)

sent_un <- corp |>
  corpus_subset(year == 1973) |>
  textstat_polarity(dict)

ggplot(sent_un) +
  geom_point() +
  aes(x = sentiment, y = reorder(doc_id, sentiment))
