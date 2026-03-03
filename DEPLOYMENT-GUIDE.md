# Netlify Deployment Guide - ASQ-3 Saudi Dashboard

## Overview
Your Quarto dashboard with the expert review system is ready for deployment to Netlify.

## Prerequisites
1. **GitHub Account** - Create one at [github.com](https://github.com) if you don't have one
2. **Git Installed** - Download from [git-scm.com](https://git-scm.com)
3. **Netlify Account** - Create free at [netlify.com](https://netlify.com)

---

## Step 1: Initialize Git Repository

```bash
cd "c:\Users\psipu\Dropbox\University of Oregon\ASQ-3 Saudi\Arabic\dashboard_saudi"

# Initialize git
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: ASQ-3 Saudi dashboard with expert review system"
```

### Create .gitignore
Create a file named `.gitignore` in your dashboard_saudi folder with:
```
_site/
.Rproj.user/
.Rhistory
.RData
.Ruserdata
node_modules/
.DS_Store
*.swp
```

---

## Step 2: Push to GitHub

1. **Create a new repository on GitHub**
   - Go to [github.com/new](https://github.com/new)
   - Name it: `asq3-saudi-dashboard`
   - Choose "Public" (for Netlify to access)
   - Click "Create repository"

2. **Push your local code to GitHub**
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/asq3-saudi-dashboard.git
   git branch -M main
   git push -u origin main
   ```
   
   Replace `YOUR_USERNAME` with your actual GitHub username.

---

## Step 3: Deploy to Netlify

### Option A: Via Netlify UI (Recommended)
1. Go to [app.netlify.com/start](https://app.netlify.com/start)
2. Click **"Connect to Git"**
3. Choose **GitHub**
4. Authorize Netlify to access your GitHub account
5. Search for and select `asq3-saudi-dashboard`
6. Leave build settings as default (Netlify auto-detects from `netlify.toml`)
7. Click **"Deploy site"**

### Option B: Via Netlify CLI
```bash
npm install -g netlify-cli

cd "c:\Users\psipu\Dropbox\University of Oregon\ASQ-3 Saudi\Arabic\dashboard_saudi"

netlify deploy --prod
```

---

## Step 4: Verify Deployment

After deployment:

1. **Check build logs** in Netlify dashboard
2. **Visit your site** at the URL shown (usually something like `https://asq3-saudi.netlify.app`)
3. **Test the expert form**:
   - Fill in all required fields
   - Rate a few sample items
   - Click Submit
   - Verify success message appears

---

## Step 5: Data File Permissions

After deployment, you need to ensure the Netlify Functions can write to `/data/evaluations/`:

1. In Netlify admin panel, go to **Site Settings**
2. Navigate to **Functions**
3. Verify functions are deploying correctly (should show `save-evaluation`)

### Manual Write Verification
If submissions fail, create the data directory:
```bash
mkdir -p "dashboard_saudi/data/evaluations"
```

---

## Step 6: Data Analysis

After experts start submitting evaluations:

```bash
# Run the analysis script
Rscript "R/analyze-expert-reviews.R"

# This generates:
# - analysis/01-experts-summary.csv
# - analysis/02-item-summary.csv
# - analysis/03-low-quality-items.csv
# - analysis/04-low-clarity-items.csv
# - analysis/05-high-variance-quality.csv
# - analysis/06-high-variance-clarity.csv
# - analysis/07-items-with-comments.csv
# - analysis/08-all-ratings.csv
# - analysis/plot-quality-distribution.png
# - analysis/plot-clarity-distribution.png
# - analysis/plot-quality-vs-clarity.png
# - analysis/plot-low-rated-items.png
```

---

## Troubleshooting

### Issue: "Build failed" in Netlify
**Solution**: Check build logs in Netlify admin panel. Common issues:
- Missing `quarto` command (should be auto-installed by Netlify)
- Missing R packages (add to `_quarto.yml` under `install-dir`)

### Issue: Form submissions fail
**Solution**: Check Netlify Functions logs:
1. Go to **Functions** in Netlify admin
2. Click **save-evaluation**
3. Check recent invocations for errors

### Issue: Data not persisting
**Solution**: 
1. Verify `/data/evaluations/` directory exists in repository
2. Use `.gitkeep` file to track empty directory:
   ```bash
   touch data/evaluations/.gitkeep
   git add data/evaluations/.gitkeep
   git commit -m "Add evaluations directory"
   git push
   ```

---

## Sharing Your Dashboard

Once deployed, share this URL with experts:
```
https://[your-netlify-site-name].netlify.app
```

They can:
1. Fill in their information
2. Rate items on quality (1-5) and clarity (1-5)
3. Add optional comments
4. Submit their evaluation

Data is automatically saved to CSV files in `/data/evaluations/`

---

## Environment Variables (If Needed)

If you later want to add authentication or notifications:

1. In Netlify admin: **Site Settings → Build & Deploy → Environment**
2. Add key-value pairs like:
   ```
   SLACK_WEBHOOK_URL = https://hooks.slack.com/...
   EMAIL_NOTIFICATION = true
   ```
3. Netlify Functions can access via: `process.env.SLACK_WEBHOOK_URL`

---

## Monitoring & Maintenance

### Weekly Tasks
- Check Netlify Functions logs for errors
- Download latest evaluation CSV to backup data

### Monthly Tasks
- Run `analyze-expert-reviews.R` to check for problematic items
- Review expert comments in `/data/evaluations/items-with-comments.csv`

### Quarterly Tasks
- Archive completed evaluations: `cp -r data/evaluations data/evaluations-backup-YYYY-Q#`
- Prepare analysis report for stakeholders

---

## Support Resources

- **Quarto Docs**: https://quarto.org/docs
- **Netlify Docs**: https://docs.netlify.com
- **R Data Analysis**: See `README-EXPERT-REVIEW.md`

---

## Next Steps

1. ✅ Create GitHub repository
2. ✅ Deploy to Netlify
3. ✅ Test expert form
4. ✅ Collect evaluations
5. ✅ Analyze results with R script
6. ✅ Present findings to IRB/research team
