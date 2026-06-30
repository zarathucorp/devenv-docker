repos <- c(
  "jinseob2kim/jstable",
  "jinseob2kim/jskm",
  "emitanaka/shinycustomloader",
  "Appsilon/shiny.i18n",
  "metrumresearchgroup/sinew",
  "jinseob2kim/jsmodule",
  "yihui/xaringan",
  "emitanaka/anicon",
  "sahirbhatnagar/manhattanly"
)

failed <- character()

for (repo in repos) {
  message("Installing GitHub package: ", repo)
  tryCatch(
    remotes::install_github(repo, dependencies = NA, upgrade = "never"),
    error = function(err) {
      failed <<- c(failed, repo)
      message("Failed to install ", repo, ": ", conditionMessage(err))
    }
  )
}

if (length(failed) > 0) {
  stop("GitHub package installation failed: ", paste(failed, collapse = ", "))
}
