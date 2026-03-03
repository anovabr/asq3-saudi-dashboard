#!/usr/bin/env Rscript
cat("Checking DT package...\n")
if (!require('DT', quietly = TRUE)) {
  cat("Installing DT...\n")
  install.packages('DT', repos='http://cran.r-project.org')
  library(DT)
} else {
  cat("DT package already installed.\n")
}
cat("DT version:", packageVersion("DT"), "\n")
