#!/usr/bin/env Rscript
# ASQ-3 Saudi Expert Review Analysis
# This script analyzes expert evaluations and generates reports

library(tidyverse)
library(readr)
library(knitr)
library(ggplot2)

# ============================================================================
# 1. LOAD DATA
# ============================================================================

load_evaluation_data <- function(data_dir = "data/evaluations") {
  experts <- tryCatch(
    read_csv(file.path(data_dir, "experts.csv"), show_col_types = FALSE),
    error = function(e) {
      message("No experts.csv found")
      return(tibble())
    }
  )
  
  ratings <- tryCatch(
    read_csv(file.path(data_dir, "item-ratings.csv"), show_col_types = FALSE),
    error = function(e) {
      message("No item-ratings.csv found")
      return(tibble())
    }
  )
  
  list(experts = experts, ratings = ratings)
}

# ============================================================================
# 2. SUMMARY STATISTICS
# ============================================================================

summarize_evaluations <- function(experts, ratings) {
  if (nrow(experts) == 0 || nrow(ratings) == 0) {
    message("No data to summarize")
    return(NULL)
  }
  
  cat("\n=== EXPERT REVIEW SUMMARY ===\n\n")
  
  # Expert demographics
  cat("Total Experts:", nrow(experts), "\n")
  cat("\nExpertise Distribution:\n")
  print(table(experts$expertise))
  
  cat("\nArabic Proficiency:\n")
  print(table(experts$language))
  
  cat("\nYears of Experience (Mean):", round(mean(experts$yearsExperience, na.rm = TRUE), 1), "\n")
  
  # Rating distributions
  cat("\n=== RATING DISTRIBUTIONS ===\n\n")
  
  cat("Quality Ratings:\n")
  print(table(ratings$quality, useNA = "ifany"))
  
  cat("\nClarity Ratings:\n")
  print(table(ratings$clarity, useNA = "ifany"))
  
  # Item-level summary
  cat("\n=== ITEM-LEVEL SUMMARY ===\n\n")
  
  item_summary <- ratings %>%
    group_by(itemIndex) %>%
    summarize(
      n_ratings = n(),
      n_experts = n_distinct(expertEmail),
      mean_quality = mean(quality, na.rm = TRUE),
      sd_quality = sd(quality, na.rm = TRUE),
      min_quality = min(quality, na.rm = TRUE),
      max_quality = max(quality, na.rm = TRUE),
      mean_clarity = mean(clarity, na.rm = TRUE),
      sd_clarity = sd(clarity, na.rm = TRUE),
      min_clarity = min(clarity, na.rm = TRUE),
      max_clarity = max(clarity, na.rm = TRUE),
      has_comments = sum(!is.na(comment) & comment != "") > 0,
      .groups = "drop"
    )
  
  return(item_summary)
}

# ============================================================================
# 3. IDENTIFY PROBLEMATIC ITEMS
# ============================================================================

identify_concerns <- function(ratings, item_summary, quality_threshold = 3, clarity_threshold = 3, variance_threshold = 1.2) {
  
  # Low average ratings
  low_quality <- item_summary %>%
    filter(mean_quality < quality_threshold) %>%
    arrange(mean_quality)
  
  low_clarity <- item_summary %>%
    filter(mean_clarity < clarity_threshold) %>%
    arrange(mean_clarity)
  
  # High disagreement (high variance)
  high_variance_quality <- item_summary %>%
    filter(sd_quality > variance_threshold & !is.na(sd_quality)) %>%
    arrange(desc(sd_quality))
  
  high_variance_clarity <- item_summary %>%
    filter(sd_clarity > variance_threshold & !is.na(sd_clarity)) %>%
    arrange(desc(sd_clarity))
  
  # Items with many comments
  items_with_comments <- ratings %>%
    filter(!is.na(comment) & comment != "") %>%
    group_by(itemIndex) %>%
    summarize(
      n_comments = n(),
      comments = paste(comment, collapse = " | "),
      .groups = "drop"
    ) %>%
    arrange(desc(n_comments))
  
  list(
    low_quality = low_quality,
    low_clarity = low_clarity,
    high_variance_quality = high_variance_quality,
    high_variance_clarity = high_variance_clarity,
    items_with_comments = items_with_comments
  )
}

# ============================================================================
# 4. GENERATE REPORTS
# ============================================================================

generate_report <- function(experts, ratings, item_summary, concerns, output_dir = "analysis") {
  
  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # 4.1 - Expert Summary
  expert_summary <- experts %>%
    select(timestamp, fullName, email, institution, expertise, yearsExperience, language) %>%
    arrange(timestamp)
  
  write_csv(expert_summary, file.path(output_dir, "01-experts-summary.csv"))
  cat("✓ Saved: 01-experts-summary.csv\n")
  
  # 4.2 - Item Summary
  write_csv(item_summary, file.path(output_dir, "02-item-summary.csv"))
  cat("✓ Saved: 02-item-summary.csv\n")
  
  # 4.3 - Low Quality Items
  if (nrow(concerns$low_quality) > 0) {
    write_csv(concerns$low_quality, file.path(output_dir, "03-low-quality-items.csv"))
    cat("✓ Saved: 03-low-quality-items.csv\n")
  }
  
  # 4.4 - Low Clarity Items
  if (nrow(concerns$low_clarity) > 0) {
    write_csv(concerns$low_clarity, file.path(output_dir, "04-low-clarity-items.csv"))
    cat("✓ Saved: 04-low-clarity-items.csv\n")
  }
  
  # 4.5 - High Variance Items
  if (nrow(concerns$high_variance_quality) > 0) {
    write_csv(concerns$high_variance_quality, file.path(output_dir, "05-high-variance-quality.csv"))
    cat("✓ Saved: 05-high-variance-quality.csv\n")
  }
  
  if (nrow(concerns$high_variance_clarity) > 0) {
    write_csv(concerns$high_variance_clarity, file.path(output_dir, "06-high-variance-clarity.csv"))
    cat("✓ Saved: 06-high-variance-clarity.csv\n")
  }
  
  # 4.6 - Items with Comments
  if (nrow(concerns$items_with_comments) > 0) {
    write_csv(concerns$items_with_comments, file.path(output_dir, "07-items-with-comments.csv"))
    cat("✓ Saved: 07-items-with-comments.csv\n")
  }
  
  # 4.7 - All raw ratings
  write_csv(ratings, file.path(output_dir, "08-all-ratings.csv"))
  cat("✓ Saved: 08-all-ratings.csv\n")
}

# ============================================================================
# 5. VISUALIZATIONS
# ============================================================================

create_visualizations <- function(ratings, item_summary, output_dir = "analysis") {
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Distribution of Quality Ratings
  p1 <- ratings %>%
    filter(!is.na(quality)) %>%
    ggplot(aes(x = factor(quality))) +
    geom_bar(fill = "#1F6AA5", alpha = 0.8) +
    labs(title = "Distribution of Quality Ratings", x = "Quality Rating (1-5)", y = "Count") +
    theme_minimal(base_size = 12)
  
  ggsave(file.path(output_dir, "plot-quality-distribution.png"), p1, width = 8, height = 5)
  cat("✓ Saved: plot-quality-distribution.png\n")
  
  # Distribution of Clarity Ratings
  p2 <- ratings %>%
    filter(!is.na(clarity)) %>%
    ggplot(aes(x = factor(clarity))) +
    geom_bar(fill = "#2E8B9E", alpha = 0.8) +
    labs(title = "Distribution of Clarity Ratings", x = "Clarity Rating (1-5)", y = "Count") +
    theme_minimal(base_size = 12)
  
  ggsave(file.path(output_dir, "plot-clarity-distribution.png"), p2, width = 8, height = 5)
  cat("✓ Saved: plot-clarity-distribution.png\n")
  
  # Quality vs Clarity Scatter
  p3 <- ratings %>%
    filter(!is.na(quality) & !is.na(clarity)) %>%
    ggplot(aes(x = quality, y = clarity)) +
    geom_jitter(width = 0.2, height = 0.2, alpha = 0.5, color = "#F39C12") +
    geom_smooth(method = "lm", color = "#1F6AA5", fill = "#1F6AA5", alpha = 0.2) +
    labs(title = "Quality vs Clarity Ratings", x = "Quality Rating", y = "Clarity Rating") +
    theme_minimal(base_size = 12)
  
  ggsave(file.path(output_dir, "plot-quality-vs-clarity.png"), p3, width = 8, height = 5)
  cat("✓ Saved: plot-quality-vs-clarity.png\n")
  
  # Low-rated items
  if (nrow(item_summary) > 0) {
    p4 <- item_summary %>%
      filter(mean_quality < 3 | mean_clarity < 3) %>%
      arrange(mean_quality) %>%
      head(20) %>%
      mutate(itemIndex = factor(itemIndex, levels = itemIndex)) %>%
      pivot_longer(cols = starts_with("mean_"), names_to = "metric", values_to = "rating") %>%
      ggplot(aes(x = itemIndex, y = rating, fill = metric)) +
      geom_col(position = "dodge") +
      labs(title = "Items with Ratings Below 3", x = "Item Index", y = "Mean Rating") +
      theme_minimal(base_size = 11) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    
    ggsave(file.path(output_dir, "plot-low-rated-items.png"), p4, width = 12, height = 6)
    cat("✓ Saved: plot-low-rated-items.png\n")
  }
}

# ============================================================================
# 6. MAIN EXECUTION
# ============================================================================

main <- function() {
  cat("\n╔════════════════════════════════════════════════════════════╗\n")
  cat("║      ASQ-3 Saudi Expert Review Analysis Report            ║\n")
  cat("╚════════════════════════════════════════════════════════════╝\n\n")
  
  # Load data
  data <- load_evaluation_data("data/evaluations")
  
  if (nrow(data$experts) == 0) {
    cat("No expert evaluation data found. Please ensure experts have submitted reviews.\n")
    return(invisible(NULL))
  }
  
  # Generate summaries
  item_summary <- summarize_evaluations(data$experts, data$ratings)
  
  # Identify concerns
  concerns <- identify_concerns(data$ratings, item_summary)
  
  # Generate reports
  cat("\n=== GENERATING REPORTS ===\n")
  generate_report(data$experts, data$ratings, item_summary, concerns)
  
  # Create visualizations
  cat("\n=== CREATING VISUALIZATIONS ===\n")
  create_visualizations(data$ratings, item_summary)
  
  cat("\n✓ Analysis complete! Check the 'analysis' folder for results.\n\n")
  
  invisible(list(
    experts = data$experts,
    ratings = data$ratings,
    item_summary = item_summary,
    concerns = concerns
  ))
}

# Run if executed directly
if (!interactive()) {
  main()
}
