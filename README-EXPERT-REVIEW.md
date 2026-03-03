# ASQ-3 Saudi Expert Review System

## Overview
This system collects expert evaluations of ASQ-3 items for quality, clarity, and cultural appropriateness in Arabic.

## Data Collection

### Expert Information CSV (`data/evaluations/experts.csv`)
Contains one row per expert with:
- `timestamp` - ISO timestamp of submission
- `fullName` - Expert name
- `email` - Expert email
- `institution` - Associated organization
- `expertise` - Area of expertise
- `yearsExperience` - Years in field
- `language` - Arabic proficiency level
- `additionalInfo` - Additional background

### Item Ratings CSV (`data/evaluations/item-ratings.csv`)
Contains one row per item rating with:
- `timestamp` - Submission timestamp
- `expertEmail` - Expert identifier
- `expertName` - Expert name
- `itemIndex` - Item number
- `quality` - Quality rating (1-5)
- `clarity` - Clarity rating (1-5)
- `comment` - Expert comments

### Raw JSON Backups
Each submission saved as `evaluation-[timestamp].json` for backup

## Analysis in R

### Load and View Data
```r
library(tidyverse)
library(readr)

# Load expert information
experts <- read_csv('data/evaluations/experts.csv')

# Load item ratings
ratings <- read_csv('data/evaluations/item-ratings.csv')

# View data
head(experts)
head(ratings)
```

### Summary Statistics
```r
# Quality and clarity means by item
item_summary <- ratings %>%
  group_by(itemIndex) %>%
  summarize(
    n_experts = n_distinct(expertEmail),
    mean_quality = mean(quality, na.rm = TRUE),
    sd_quality = sd(quality, na.rm = TRUE),
    mean_clarity = mean(clarity, na.rm = TRUE),
    sd_clarity = sd(clarity, na.rm = TRUE),
    .groups = 'drop'
  )

# Experts by expertise
experts_by_expertise <- experts %>%
  count(expertise, sort = TRUE)

# Distribution of ratings
ratings %>%
  ggplot(aes(x = quality, fill = factor(quality))) +
  geom_histogram(binwidth = 0.5) +
  facet_wrap(~clarity) +
  theme_minimal()
```

### Identify Problematic Items
```r
# Items with low average ratings
low_quality <- item_summary %>%
  filter(mean_quality < 3)

# Items with high variance (disagreement)
high_variance <- item_summary %>%
  filter(sd_quality > 1.5 | sd_clarity > 1.5)

# Items with comments
items_with_comments <- ratings %>%
  filter(comment != '' & !is.na(comment)) %>%
  select(itemIndex, expertName, comment)
```

### Export Results
```r
# Write summary tables
write_csv(item_summary, 'analysis/item-summary.csv')
write_csv(low_quality, 'analysis/low-quality-items.csv')
write_csv(items_with_comments, 'analysis/items-with-comments.csv')
```

## Deployment

1. Push code to GitHub
2. Connect repo to Netlify
3. Netlify automatically:
   - Builds Quarto dashboard
   - Deploys Netlify Functions
   - Collects expert evaluations in `/data/evaluations/`

4. Download evaluation data periodically:
   - From Netlify dashboard
   - Via Git (if you commit the data folder)
   - Via external service (Zapier, Make)

## Security Considerations

- This implementation saves data locally on Netlify
- For production: consider connecting to external database (MongoDB, PostgreSQL)
- Evaluate expert data collection requirements (HIPAA, IRB approval, etc.)
- Implement authentication if responses should be tracked per expert

## Local Testing

To test locally:
```bash
# Install dependencies
cd netlify/functions
npm install

# Run Quarto preview
quarto preview item-bank.qmd

# Test function locally with Netlify CLI
netlify functions:invoke save-evaluation
```
