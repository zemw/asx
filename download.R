library(httr)
library(rvest)
library(stringi)
library(magrittr)
library(jsonlite)
library(tidyverse)
library(knitr)
library(xml2)

# ACTION: modify the URL here
column_url <- "http://www.aisixiang.com/thinktank/LuXun.html"

# real whole page
page <- read_html(column_url, encoding = "GBK")

# links to article
links <- page %>% html_elements("a[target=\"_blank\"]")

# parse all links into a table
table <-
  links %>% map_df(function(link) {
    list(
      title = html_text(link),
      href = html_attr(link, "href"),
      id = html_attr(link, "href") %>% stri_extract(regex = "[0-9]+")
    )
  }) %>% drop_na(id)

# TODO: discard long articles/books

message(sprintf("%d articles found. Downloading...", nrow(table)))


# create directory if does not exist
# use the author's name as the directory name
dir_name <- stri_extract_first(basename(column_url), regex = "\\w+")
dir.create(dir_name, showWarnings = F)


# download all articles and save to local files 
json_url <- "http://www.aisixiang.com/data/view_json.php?id="

table %>% 
  pmap(safely(function(title, href, id) {
    raw <- GET(paste0(json_url, id))
    json <- content(raw, "text") %>% fromJSON()
    body <- read_html(json$content) %>% html_element("body")
    # modify html: add title
    xml_new_root("h2", title) %>% 
      xml_add_sibling(body) %>% 
      minimal_html(title) %>% 
      write_xml(sprintf("%s/%s.html",dir_name, title))
  }))

message(sprintf("Completed: %s", file.path(getwd(), dir_name)))
