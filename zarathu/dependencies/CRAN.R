cran_repo <- Sys.getenv("CRAN_REPO", "https://cloud.r-project.org")
options(repos = c(CRAN = cran_repo))

packages <- c(
  "shiny",
  "quarto",
  "rmarkdown",
  "markdown",
  "DT",
  "data.table",
  "ggplot2",
  "devtools",
  "epiDisplay",
  "tableone",
  "svglite",
  "plotROC",
  "pROC",
  "labelled",
  "geepack",
  "lme4",
  "PredictABEL",
  "shinythemes",
  "maxstat",
  "Cairo",
  "future",
  "promises",
  "GGally",
  "fst",
  "blogdown",
  "metafor",
  "roxygen2",
  "MatchIt",
  "distill",
  "lubridate",
  "testthat",
  "rversions",
  "spelling",
  "rhub",
  "remotes",
  "ggpmisc",
  "RefManageR",
  "tidyr",
  "shinytest",
  "ggpubr",
  "kableExtra",
  "timeROC",
  "survC1",
  "survIDINRI",
  "colourpicker",
  "shinyWidgets",
  "devEMF",
  "see",
  "aws.s3",
  "epiR",
  "zip",
  "keyring",
  "shinymanager",
  "kappaSize",
  "irr",
  "gsDesign",
  "jtools",
  "svydiags",
  "shinyBS",
  "highcharter",
  "forestplot",
  "qgraph",
  "bootnet",
  "rhandsontable",
  "meta",
  "showtext",
  "officer",
  "rvg",
  "httr",
  "shinybrowser",
  "pins",
  "paws.storage",
  "otelsdk"
)

installed <- rownames(installed.packages())
missing <- setdiff(packages, installed)

if (length(missing) == 0) {
  message("All CRAN packages are already installed.")
} else {
  ncpus <- max(1L, parallel::detectCores(logical = TRUE) - 1L)
  message("Installing CRAN packages from ", cran_repo, ": ", paste(missing, collapse = ", "))
  install.packages(missing, dependencies = NA, Ncpus = ncpus)
}

installed_after <- rownames(installed.packages())
still_missing <- setdiff(packages, installed_after)

if (length(still_missing) > 0) {
  stop("Missing CRAN packages after installation: ", paste(still_missing, collapse = ", "))
}

message("Verified CRAN packages: ", length(packages), " requested, 0 missing.")
