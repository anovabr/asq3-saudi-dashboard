suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(tibble)
})

source_path <- file.path('..', 'R Base ASQ Saudi.RData')
out_path <- file.path('data', 'dashboard_data.rds')

if (!file.exists(source_path)) {
  stop('Source data file not found: ', source_path)
}

load(source_path)

if (!exists('df_all')) {
  df_names <- ls(pattern = '^df_[0-9]+$')
  if (length(df_names) == 0) {
    stop('No `df_all` object or `df_XX` objects found after loading source data.')
  }

  df_all <- map_dfr(df_names, function(nm) {
    quest_value <- as.numeric(sub('df_', '', nm))
    get(nm) %>%
      mutate(quest = quest_value) %>%
      select(
        quest, age, birth_date, gender, city,
        matches('^((c|gm|fm|cg|ps)[0-9]+|(c|gm|fm|cg|ps)_sum)$')
      )
  })
}

domain_labels <- c(
  c = 'Communication',
  gm = 'Gross motor',
  fm = 'Fine motor',
  cg = 'Problem-solving',
  ps = 'Personal-social'
)

extract_quest <- function(name) {
  as.integer(gsub('^df_0*', '', name))
}

pick_fit_value <- function(fit_vec, robust_name, default_name) {
  if (!is.null(fit_vec[[robust_name]]) && !is.na(fit_vec[[robust_name]])) {
    return(as.numeric(fit_vec[[robust_name]]))
  }
  if (!is.null(fit_vec[[default_name]]) && !is.na(fit_vec[[default_name]])) {
    return(as.numeric(fit_vec[[default_name]]))
  }
  NA_real_
}

pick_fit_max <- function(fit_vec, candidates) {
  vals <- unlist(fit_vec[candidates], use.names = FALSE)
  vals <- as.numeric(vals)
  vals <- vals[!is.na(vals)]
  if (length(vals) == 0) NA_real_ else max(vals)
}

pick_fit_min <- function(fit_vec, candidates) {
  vals <- unlist(fit_vec[candidates], use.names = FALSE)
  vals <- as.numeric(vals)
  vals <- vals[!is.na(vals)]
  if (length(vals) == 0) NA_real_ else min(vals)
}

cfa_fit_by_quest <- tibble()
cfa_loadings <- tibble()

if (exists('results') && is.list(results) && length(results) > 0) {
  cfa_fit_by_quest <- imap_dfr(results, function(res, nm) {
    fit_vec <- tryCatch(res$summary$fit, error = function(e) NULL)
    if (is.null(fit_vec)) return(tibble())

    tibble(
      quest = extract_quest(nm),
      cfi = pick_fit_max(fit_vec, c('cfi.robust', 'cfi.scaled', 'cfi')),
      tli = pick_fit_max(fit_vec, c('tli.robust', 'tli.scaled', 'tli')),
      rmsea = pick_fit_min(fit_vec, c('rmsea.robust', 'rmsea.scaled', 'rmsea')),
      srmr = pick_fit_value(fit_vec, 'srmr', 'srmr'),
      chisq = pick_fit_value(fit_vec, 'chisq.scaled', 'chisq'),
      df = pick_fit_value(fit_vec, 'df.scaled', 'df')
    )
  }) %>%
    arrange(quest) %>%
    mutate(
      cfi = round(cfi, 3),
      tli = round(tli, 3),
      rmsea = round(rmsea, 3),
      srmr = round(srmr, 3),
      chisq = round(chisq, 2),
      df = round(df, 0)
    )

  cfa_loadings <- imap_dfr(results, function(res, nm) {
    pe <- tryCatch(res$summary$pe, error = function(e) NULL)
    if (is.null(pe)) return(tibble())

    as_tibble(pe) %>%
      filter(op == '=~') %>%
      transmute(
        quest = extract_quest(nm),
        factor = lhs,
        item = rhs,
        std_loading = round(std.all, 3),
        pvalue = round(pvalue, 3)
      )
  }) %>%
    arrange(quest, factor, item)
}

cache <- list(
  df_all = df_all,
  cfa_fit_by_quest = cfa_fit_by_quest,
  cfa_loadings = cfa_loadings,
  built_at = as.character(Sys.time())
)

saveRDS(cache, out_path)
cat('Saved cache to:', out_path, '\n')
cat('Rows in df_all:', nrow(df_all), '\n')
cat('Rows in cfa_fit_by_quest:', nrow(cfa_fit_by_quest), '\n')
cat('Rows in cfa_loadings:', nrow(cfa_loadings), '\n')
