## Install packages
# install.packages(c("ellmer", "jsonlite"))

## Basic call --------------------------
library(ellmer)

llama <- chat_openai(
  base_url = "https://api.scaleway.ai/v1",
  api_key = Sys.getenv("SCW_SECRET_KEY"),
  model = "llama-3.3-70b-instruct"
)

prompt <- "Tell me a joke about professors of Middle Eastern Studies"

llama$chat(prompt)

## Manage conversation --------------------------

# First conversation
llama$chat("I'm Thomas. Which model are you?")
llama$chat("What's my name again?")
llama$get_tokens() # token use in conversation

# Re-initiate chat object
llama <- chat_openai(
  base_url = "https://api.scaleway.ai/v1",
  api_key = Sys.getenv("SCW_SECRET_KEY"),
  model = "llama-3.3-70b-instruct"
)

# Second conversation
llama$chat("What's my name?")
llama$get_tokens()

# Token use in session
token_usage()

## Add parameters --------------------------

llama <- chat_openai(
  base_url = "https://api.scaleway.ai/v1",
  api_key = Sys.getenv("SCW_SECRET_KEY"),
  model = "llama-3.3-70b-instruct",
  params = params(
    max_tokens = 1000,
    temperature = 1.9,
    seed = 123
  )
)

## Set system prompt --------------------------

llama <- chat_openai(
  base_url = "https://api.scaleway.ai/v1",
  api_key = Sys.getenv("SCW_SECRET_KEY"),
  model = "llama-3.3-70b-instruct",
  system_prompt = "
  You are a specialist of Middle East history
  "
)

## Build user prompts --------------------------

## With tidyverse functions -------
library(tidyverse)

# Create example file
resp <- llama$chat(
  "Explain the Iran-Iraq war in 500 words",
  echo = FALSE
)
write(resp, "explanation.md")

# Combine strings
prelude <- "Summarize this: \n\n"

text <- read_file("explanation.md")

prompt <- str_c(prelude, text)
# Alternatively:
# prompt <- str_glue("{prelude}{text}")

llama$chat(prompt)

## With ellmer's interpolate functions -------
greeting <- "Hello {{name}}."

# Provide variable explicitly
interpolate(greeting, name = "everybody")

# Or let it fetch variable from environment
name <- "everybody"
interpolate(greeting)

# Create prompt file with variables
write(
  "Who ruled {{country}} in {{year}}?",
  "prompt.md"
)

# Create prompt
prompt <- interpolate_file(
  "prompt.md",
  country = "Iraq",
  year = 1968
)

llama$chat(prompt)

## Combine with iteration --------------

# Create prompt file with variable
write(
  "Who ruled Iraq in {{year}}?
  Respond with just the name.",
  "prompt2.md"
)

# Create custom function
get_ruler <- function(year) {
  prompt <- interpolate_file(
    "prompt2.md",
    year = year
  )
  llama$chat(prompt)
}

# test it
get_ruler(1988)

# Iterate
years <- 1960:1963
map(years, get_ruler)

## Attach files --------------

# Initiate vision model
pixtral <- chat_openai(
  base_url = "https://api.scaleway.ai/v1",
  api_key = Sys.getenv("SCW_SECRET_KEY"),
  model = "pixtral-12b-2409"
)
# If Scaleway is rate-limiting you, try Mistral (also free):
# pixtral <- chat_mistral(model = "pixtral-12b-2409")

# Using example files from week 7
pixtral$chat(
  "What's in this image?",
  content_image_file("sdf_014.jpg")
)

# Supply multiple
pixtral$chat(
  "Compare these two images.",
  content_image_file("sdf_014.jpg"),
  content_image_file("sdf_019.jpg"),
)

# or provide a URL
pixtral$chat(
  "What's in this image?",
  content_image_url("https://www.r-project.org/Rlogo.png")
)

## Activate JSON mode ----------------------------

library(jsonlite)

# Initiate chat object with JSON mode
llama <- chat_openai(
  base_url = "https://api.scaleway.ai/v1",
  api_key = Sys.getenv("SCW_SECRET_KEY"),
  model = "llama-3.3-70b-instruct",
  system_prompt = "
  You are a helpful assistant who
  returns nicely structured JSON.
  Always return JSON only.
  ",
  params = params(
    response_format = list(
      type = "json_object"
    )
  )
)

# Call API
resp <- llama$chat("
  List the capitals of all
  Middle Eastern countries.
")

# Convert to list
capitals <- fromJSON(resp)

# First element is nice dataframe
View(capitals[[1]])

## Prompt for other output formats --------------

# Re-initiate without JSON mode
llama <- chat_openai(
  base_url = "https://api.scaleway.ai/v1",
  api_key = Sys.getenv("SCW_SECRET_KEY"),
  model = "llama-3.3-70b-instruct"
)

llama$chat("
  Make me a diagram of the causes of the
  1948 Yemen war. Return as Mermaid code
  without any commentary.
")

llama$chat("
  Write me a 300-word note on the 1948
  Yemen war in Turkish and in LaTeX format.
  Return LaTeX code without any commentary.
")

llama$chat("
  Here is some data in CSV format:

  country,gdp,pop
  Morocco,3500,37
  Algeria,4700,47

  Return it to me as a markdown table
  without any commentary.
")

## Structured output basics --------------

llama$chat_structured(
  "Saddam Hussein was born in 1937.",
  type = type_object(
    name = type_string(),
    born_year = type_number(),
  )
)

## Structured output schema options --------------

# Create schema
profile <- type_object(
  "A political leader",
  name = type_string("The person's full name"),
  country = type_string("The country that he or she governed"),
  birth = type_number("The person's year of birth"),
  death = type_number("The person's year of death"),
  rule = type_string("The time period he or she governed"),
  fave_colour = type_string("The person's favourite colour", required = FALSE)
)

# Example input from Wikipedia
text <- "
  Saddam Hussein (28 April 1937 – 30 December 2006)
  was an Iraqi politician and revolutionary who
  served as the fifth president of Iraq from 1979
  until his overthrow in 2003 during the U.S.
  invasion of Iraq.
"

llama$chat_structured(text, type = profile)

## Tools --------------


## Image classification --------------

# NB: Use model with vision capability
pixtral$chat_structured(
  content_image_file("sdf_014.jpg"),
  type = type_object(
    primary_motif = type_string(),
    primary_colour = type_string()
  )
)

# If Scaleway is rate-limiting you, try Mistral (also free):
# pixtral <- chat_mistral(model = "pixtral-12b-2409")

pixtral$chat_structured(
  content_image_file("sdf_014.jpg"),
  type = type_object(
    energy = type_enum(
      "The energy in the picture",
      values = c("serene", "dramatic")
    )
  )
)

# Sentiment analysis --------------

type_sentiment <- type_object(
  energy = type_enum(
    "The sentiment of the text",
    values = c("positive", "negative", "neutral")
  ),
)

text <- "The hostilities between Libyan militias seem unlikely to end."
llama$chat_structured(text, type = type_sentiment)

# Polarity with confidence scores
type_sentiment <- type_object(
  "Assign a sentiment score to the text. The scores should always sum to 1.",
  positive = type_number("Positive sentiment score, ranging from 0.0 to 1.0."),
  negative = type_number("Negative sentiment score, ranging from 0.0 to 1.0."),
  neutral = type_number("Neutral sentiment score, ranging from 0.0 to 1.0.")
)

text <- "Lebanese food is better than Egyptian food."
llama$chat_structured(text, type = type_sentiment)

# valence
type_sentiment <- type_object(
  "Assign emotional ratings to the text.",
  pleasure = type_number("Score ranging from 1 to 9 (highest)"),
  arousal = type_number("Score ranging from 1 to 9 (highest)"),
  dominance = type_number("Score ranging from 1 to 9 (highest)")
)

text <- "I just love Iranian cinema."
llama$chat_structured(text, type = type_sentiment)

## Named entity recognition --------------

# Example input from Wikipedia
text <- "
Sayyid Ibrahim Husayn Shadhili Qutb (9 October 1906 – 29 August 1966)
was an Egyptian political theorist and revolutionary who was a leading member
of the Muslim Brotherhood.
"

# Schema
type_named_entity <- type_object(
  "Extract named entities from the text.",
  name = type_string("The extracted entity name."),
  type = type_enum("The entity type", c("person", "organization", "location", "datetime")),
  context = type_string("The context in which the entity appears in the text.")
)

type_named_entities <- type_array(items = type_named_entity)

llama$chat_structured(text, type = type_named_entities)

## Example of neuron made in R --------------
neuron <- list(
  weights = c(0.5, -0.5),
  bias = 0,
  activate = function(x) {
    1 / (1 + exp(-x))
  }
)
