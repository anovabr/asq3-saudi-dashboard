suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
})

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

cache_path <- file.path("data", "dashboard_data.rds")
cache_data <- NULL
if (file.exists(cache_path)) {
  cache_data <- readRDS(cache_path)
}

if (!is.null(cache_data) && "df_all" %in% names(cache_data)) {
  df_all <- cache_data$df_all
} else {
  rdata_path <- file.path("..", "R Base ASQ Saudi.RData")
  if (file.exists(rdata_path)) {
    load(rdata_path)
  }
}

if (!exists("df_all")) {
  df_names <- ls(pattern = "^df_[0-9]+$")
  if (length(df_names) == 0) {
    stop("No `df_all` object or `df_XX` objects found after loading data.")
  }

  df_all <- map_dfr(df_names, function(nm) {
    quest_value <- as.numeric(sub("df_", "", nm))
    get(nm) %>%
      mutate(quest = quest_value) %>%
      select(
        quest, age, birth_date, gender, city,
        matches("^((c|gm|fm|cg|ps)[0-9]+|(c|gm|fm|cg|ps)_sum)$")
      )
  })
}

selected_data <- df_all %>%
  select(
    quest, age, birth_date, gender, city,
    matches("^((c|gm|fm|cg|ps)[0-9]+|(c|gm|fm|cg|ps)_sum)$")
  ) %>%
  mutate(
    quest = as.integer(quest),
    gender = as.factor(gender),
    city = as.factor(city)
  )

domain_labels <- c(
  c = "Communication",
  gm = "Gross motor",
  fm = "Fine motor",
  cg = "Problem-solving",
  ps = "Personal-social"
)

item_codes <- unlist(lapply(names(domain_labels), function(prefix) paste0(prefix, 1:6)))

extract_quest_from_text <- function(x) {
  num <- gsub("^.*?(\\d+).*$", "\\1", x)
  suppressWarnings(as.integer(num))
}

build_arabic_item_dictionary <- function(forms_dir = "..") {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    return(tibble())
  }

  files <- list.files(forms_dir, pattern = "\\.xlsx$", full.names = TRUE)
  if (length(files) == 0) {
    return(tibble())
  }

  map_dfr(files, function(path) {
    quest <- extract_quest_from_text(basename(path))
    if (is.na(quest) || quest < 2 || quest > 60) {
      return(tibble())
    }

    headers <- tryCatch(names(readxl::read_excel(path, n_max = 0)), error = function(e) NULL)
    if (is.null(headers) || length(headers) < 49) {
      return(tibble())
    }

    question_headers <- headers[20:49]
    tibble(
      quest = quest,
      item_code = item_codes,
      item_text_ar = trimws(as.character(question_headers))
    )
  }) %>%
    filter(!is.na(item_text_ar), nzchar(item_text_ar))
}

build_english_item_dictionary <- function(workbook_path = file.path("..", "Raw results - ASQ Saudi.xlsx")) {
  if (!requireNamespace("readxl", quietly = TRUE) || !file.exists(workbook_path)) {
    return(tibble())
  }

  sheet <- tryCatch(
    readxl::read_excel(workbook_path, sheet = "Items in English and Arabic", col_names = FALSE),
    error = function(e) NULL
  )
  if (is.null(sheet) || nrow(sheet) == 0) {
    return(tibble())
  }

  names(sheet) <- paste0("col", seq_len(ncol(sheet)))

  map_tbl <- sheet %>%
    transmute(
      col2 = as.character(.data$col2),
      original_variable = as.character(.data$col3),
      item_text_en = as.character(.data$col4),
      item_text_en_asq3 = as.character(.data$col5),
      item_code = tolower(trimws(as.character(.data$col6)))
    ) %>%
    mutate(
      quest_label = if_else(grepl("^[0-9]+-month$", trimws(col2)), trimws(col2), NA_character_)
    ) %>%
    fill(quest_label, .direction = "down") %>%
    mutate(
      quest = suppressWarnings(as.integer(sub("-month$", "", quest_label)))
    ) %>%
    filter(!is.na(quest), grepl("^(c|gm|fm|cg|ps)[1-6]$", item_code)) %>%
    transmute(
      quest,
      item_code,
      item_text_en = na_if(trimws(item_text_en), ""),
      item_text_en_asq3 = na_if(trimws(item_text_en_asq3), ""),
      original_variable = na_if(trimws(original_variable), "")
    ) %>%
    distinct()

  map_tbl
}

sum_vars <- paste0(names(domain_labels), "_sum")

arabic_item_dictionary <- build_arabic_item_dictionary("..")
english_item_dictionary <- build_english_item_dictionary(file.path("..", "Raw results - ASQ Saudi.xlsx"))

ai_translation_path <- file.path("data", "item_translations_ai.csv")
ai_translation_dictionary <- if (file.exists(ai_translation_path)) {
  tryCatch(
    read.csv(ai_translation_path, stringsAsFactors = FALSE, encoding = "UTF-8") %>%
      transmute(
        item_text_ar = na_if(trimws(as.character(item_text_ar)), ""),
        item_text_en_ai = na_if(trimws(as.character(item_text_en_ai)), "")
      ) %>%
      filter(!is.na(item_text_ar)) %>%
      distinct(),
    error = function(e) tibble()
  )
} else {
  tibble()
}

item_dictionary <- full_join(
  arabic_item_dictionary,
  english_item_dictionary,
  by = c("quest", "item_code")
) %>%
  left_join(ai_translation_dictionary, by = "item_text_ar") %>%
  mutate(
    item_text_en = coalesce(item_text_en_asq3, item_text_en, item_text_en_ai),
    domain_code = gsub("[0-9]+$", "", item_code),
    item_no = suppressWarnings(as.integer(gsub("^[a-z]+", "", item_code))),
    domain = recode(domain_code, !!!domain_labels),
    quest_label = paste0(quest, "-month"),
    item_id = paste0("q", quest, "_", item_code)
  ) %>%
  arrange(quest, match(domain_code, names(domain_labels)), item_no)

# Fallback for environments where readxl/source parsing is unavailable:
# use previously exported template so item bank still works.
if (nrow(item_dictionary) == 0) {
  fallback_template_path <- file.path("data", "item_quality_template.csv")
  if (file.exists(fallback_template_path)) {
    fallback_dictionary <- tryCatch(
      read.csv(fallback_template_path, stringsAsFactors = FALSE, encoding = "UTF-8"),
      error = function(e) NULL
    )

    if (!is.null(fallback_dictionary) && nrow(fallback_dictionary) > 0) {
      item_dictionary <- fallback_dictionary %>%
        transmute(
          quest = as.integer(quest),
          item_code = as.character(item_code),
          item_text_ar = na_if(trimws(as.character(item_text_ar)), ""),
          item_text_en = na_if(trimws(as.character(item_text_en)), ""),
          item_text_en_asq3 = item_text_en,
          domain = as.character(domain),
          domain_code = gsub("[0-9]+$", "", item_code),
          item_no = suppressWarnings(as.integer(gsub("^[a-z]+", "", item_code))),
          quest_label = as.character(quest_label),
          item_id = as.character(item_id)
        ) %>%
        distinct() %>%
        arrange(quest, match(domain_code, names(domain_labels)), item_no)
    }
  }
}

item_response_summary <- selected_data %>%
  select(quest, any_of(item_codes)) %>%
  pivot_longer(
    cols = -quest,
    names_to = "item_code",
    values_to = "response_raw"
  ) %>%
  mutate(
    response = na_if(trimws(as.character(response_raw)), "")
  ) %>%
  filter(!is.na(response)) %>%
  group_by(quest, item_code, response) %>%
  summarise(n = n(), .groups = "drop_last") %>%
  mutate(
    total_n = sum(n),
    pct = round(100 * n / total_n, 1)
  ) %>%
  ungroup()

item_response_wide <- item_response_summary %>%
  mutate(response_stat = paste0(response, ": ", n, " (", pct, "%)")) %>%
  group_by(quest, item_code) %>%
  summarise(response_distribution = paste(response_stat, collapse = " | "), .groups = "drop")

item_dictionary_with_stats <- item_dictionary %>%
  left_join(item_response_wide, by = c("quest", "item_code")) %>%
  arrange(quest, match(domain_code, names(domain_labels)), item_no)

item_quality_template <- item_dictionary %>%
  transmute(
    quest,
    quest_label,
    domain,
    item_no,
    item_code,
    item_id,
    item_text_ar,
    item_text_en,
    relevance_score = NA_real_,
    clarity_score = NA_real_,
    cultural_fit_score = NA_real_,
    reviewer_id = NA_character_,
    comments = NA_character_
  )

quest_counts <- selected_data %>%
  count(quest, name = "n") %>%
  arrange(quest)

overall_summary <- selected_data %>%
  summarise(
    questionnaires = n_distinct(quest),
    total_records = n(),
    mean_age = round(mean(age, na.rm = TRUE), 2),
    sd_age = round(sd(age, na.rm = TRUE), 2)
  )

gender_summary <- selected_data %>%
  count(gender, name = "n") %>%
  mutate(pct = round(100 * n / sum(n), 1))

city_summary <- selected_data %>%
  count(city, name = "n") %>%
  arrange(desc(n))

descriptive_by_quest <- selected_data %>%
  group_by(quest) %>%
  summarise(
    n = n(),
    age_mean = mean(age, na.rm = TRUE),
    age_sd = sd(age, na.rm = TRUE),
    across(all_of(sum_vars), list(mean = ~ mean(.x, na.rm = TRUE), sd = ~ sd(.x, na.rm = TRUE))),
    .groups = "drop"
  )

descriptive_msd_by_quest <- selected_data %>%
  group_by(quest) %>%
  summarise(
    n = n(),
    age = sprintf("%.2f (%.2f)", mean(age, na.rm = TRUE), sd(age, na.rm = TRUE)),
    across(
      all_of(sum_vars),
      ~ sprintf("%.2f (%.2f)", mean(.x, na.rm = TRUE), sd(.x, na.rm = TRUE))
    ),
    .groups = "drop"
  )

domain_summary_long <- selected_data %>%
  group_by(quest) %>%
  summarise(across(all_of(sum_vars), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
  pivot_longer(
    cols = all_of(sum_vars),
    names_to = "domain_code",
    values_to = "mean_score"
  ) %>%
  mutate(domain = recode(gsub("_sum$", "", domain_code), !!!domain_labels))

compute_alpha <- function(df, prefix) {
  if (!requireNamespace("psych", quietly = TRUE)) {
    return(NA_real_)
  }

  item_names <- paste0(prefix, 1:6)
  if (!all(item_names %in% names(df))) {
    return(NA_real_)
  }

  a <- tryCatch(psych::alpha(df[item_names], check.keys = FALSE), error = function(e) NULL)
  if (is.null(a)) {
    return(NA_real_)
  }

  as.numeric(a$total$raw_alpha)
}

alpha_by_quest <- selected_data %>%
  group_by(quest) %>%
  group_modify(~ {
    tibble(
      domain_code = names(domain_labels),
      domain = unname(domain_labels),
      alpha = map_dbl(names(domain_labels), function(prefix) compute_alpha(.x, prefix))
    )
  }) %>%
  ungroup() %>%
  mutate(alpha = round(alpha, 2))

cached_cfa_fit_by_quest <- NULL
cached_cfa_loadings <- NULL
if (!is.null(cache_data) && "cfa_fit_by_quest" %in% names(cache_data)) {
  cached_cfa_fit_by_quest <- cache_data$cfa_fit_by_quest
}
if (!is.null(cache_data) && "cfa_loadings" %in% names(cache_data)) {
  cached_cfa_loadings <- cache_data$cfa_loadings
}

cfa_available <- (
  (!is.null(cached_cfa_fit_by_quest) && nrow(cached_cfa_fit_by_quest) > 0) ||
    (exists("results") && is.list(results) && length(results) > 0)
)

extract_quest <- function(name) {
  as.integer(gsub("^df_0*", "", name))
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
  if (length(vals) == 0) {
    return(NA_real_)
  }
  max(vals)
}

pick_fit_min <- function(fit_vec, candidates) {
  vals <- unlist(fit_vec[candidates], use.names = FALSE)
  vals <- as.numeric(vals)
  vals <- vals[!is.na(vals)]
  if (length(vals) == 0) {
    return(NA_real_)
  }
  min(vals)
}

if (!is.null(cached_cfa_fit_by_quest) && nrow(cached_cfa_fit_by_quest) > 0) {
  cfa_fit_by_quest <- cached_cfa_fit_by_quest
  cfa_loadings <- if (!is.null(cached_cfa_loadings)) cached_cfa_loadings else tibble()
} else if (exists("results") && is.list(results) && length(results) > 0) {
  cfa_fit_by_quest <- imap_dfr(results, function(res, nm) {
    fit_vec <- tryCatch(res$summary$fit, error = function(e) NULL)
    if (is.null(fit_vec)) {
      return(tibble())
    }

    tibble(
      quest = extract_quest(nm),
      cfi = pick_fit_max(fit_vec, c("cfi.robust", "cfi.scaled", "cfi")),
      tli = pick_fit_max(fit_vec, c("tli.robust", "tli.scaled", "tli")),
      rmsea = pick_fit_min(fit_vec, c("rmsea.robust", "rmsea.scaled", "rmsea")),
      srmr = pick_fit_value(fit_vec, "srmr", "srmr"),
      chisq = pick_fit_value(fit_vec, "chisq.scaled", "chisq"),
      df = pick_fit_value(fit_vec, "df.scaled", "df")
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
    if (is.null(pe)) {
      return(tibble())
    }

    tibble::as_tibble(pe) %>%
      filter(op == "=~") %>%
      transmute(
        quest = extract_quest(nm),
        factor = lhs,
        item = rhs,
        std_loading = round(std.all, 3),
        pvalue = round(pvalue, 3)
      )
  }) %>%
    arrange(quest, factor, item)
} else {
  cfa_fit_by_quest <- tibble()
  cfa_loadings <- tibble()
}

cutoff_sd_levels <- c(0.5, 1, 1.5, 2)

cutoff_results_long <- map_dfr(cutoff_sd_levels, function(k) {
  map_dfr(sum_vars, function(v) {
    selected_data %>%
      group_by(quest) %>%
      summarise(
        domain_code = v,
        mean_score = mean(.data[[v]], na.rm = TRUE),
        sd_score = sd(.data[[v]], na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(
        sd_below = k,
        cutoff = mean_score - sd_below * sd_score
      ) %>%
      left_join(
        selected_data %>%
          group_by(quest) %>%
          summarise(
            below_n = sum(.data[[v]] < (mean(.data[[v]], na.rm = TRUE) - k * sd(.data[[v]], na.rm = TRUE)), na.rm = TRUE),
            valid_n = sum(!is.na(.data[[v]])),
            .groups = "drop"
          ),
        by = "quest"
      ) %>%
      transmute(
        sd_below,
        quest,
        domain_code,
        domain = recode(gsub("_sum$", "", domain_code), !!!domain_labels),
        cutoff = round(cutoff, 0),
        pct_below = if_else(valid_n > 0, round(100 * below_n / valid_n, 1), NA_real_)
      )
  })
}) %>%
  arrange(sd_below, quest, domain)

cutoff_results_wide <- cutoff_results_long %>%
  mutate(value = if_else(is.na(pct_below), NA_character_, sprintf("%s (%.1f%%)", cutoff, pct_below))) %>%
  select(sd_below, quest, domain, value) %>%
  pivot_wider(names_from = domain, values_from = value) %>%
  arrange(sd_below, quest)
