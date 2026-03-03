# Quick Start: ASQ-3 Saudi Expert Review System

## 🎯 What You Now Have

A complete **professional expert evaluation system** for rating the quality and clarity of 630 ASQ-3 items. Experts can:

1. **Submit expert info** (name, email, institution, expertise, years of experience, Arabic proficiency)
2. **Rate items** on Quality (1-5) and Clarity (1-5) scales
3. **Add comments** for specific items
4. **Submit data** which auto-saves to CSV files

---

## 📁 File Overview

| File | Purpose | Status |
|------|---------|--------|
| **item-bank.qmd** | Expert evaluation form interface | ✅ 700+ lines, professional design |
| **netlify/functions/save-evaluation.js** | Backend API to save ratings | ✅ Handles CSV export |
| **netlify.toml** | Deployment configuration | ✅ Tells Netlify how to build |
| **R/analyze-expert-reviews.R** | Data analysis script | ✅ Generates reports + visualizations |
| **DEPLOYMENT-GUIDE.md** | How to deploy to Netlify | 📖 Read first! |
| **README-EXPERT-REVIEW.md** | Data structure & analysis guide | 📖 Technical reference |
| **IMPLEMENTATION-CHECKLIST.md** | What's been implemented | 📊 Full feature list |

---

## 🚀 5-Minute Deployment

### 1. Install Git (if needed)
Download from: https://git-scm.com/download/win

### 2. Initialize & Push to GitHub
```bash
cd "c:\Users\psipu\Dropbox\University of Oregon\ASQ-3 Saudi\Arabic\dashboard_saudi"

git init
git add .
git commit -m "ASQ-3 Saudi expert review system"

# Create repo on github.com/new first, then:
git remote add origin https://github.com/YOUR_USERNAME/asq3-saudi-dashboard.git
git branch -M main
git push -u origin main
```

### 3. Deploy on Netlify
- Go to https://app.netlify.com/start
- Click **"Connect to Git"** → GitHub
- Select `asq3-saudi-dashboard` repository
- Click **"Deploy site"**
- Wait ~2 minutes
- **Done!** You'll get a live URL

### 4. Test
- Visit your Netlify URL
- Fill in test expert info
- Rate 2-3 items
- Click Submit
- Should see success message ✅

---

## 💾 Where Data Goes

After experts submit evaluations:

```
dashboard_saudi/data/evaluations/
├── experts.csv           # One row per expert (name, email, institution, expertise, years, language)
├── item-ratings.csv     # One row per item per expert (item#, quality rating, clarity rating, comments)
└── [timestamp].json     # Complete submission backup as JSON
```

**Download these CSVs** to analyze in Excel, R, or your preferred tool.

---

## 📊 Analyze Results

After collecting evaluations, run:

```bash
cd dashboard_saudi
Rscript R/analyze-expert-reviews.R
```

This generates:
- **01-experts-summary.csv** - Expert demographics
- **02-item-summary.csv** - Mean quality/clarity per item
- **03-low-quality-items.csv** - Items rated <3.0 quality
- **04-low-clarity-items.csv** - Items rated <3.0 clarity
- **05-high-variance-quality.csv** - Items with disagreement among experts
- **06-high-variance-clarity.csv** - Items with disagreement
- **07-items-with-comments.csv** - Expert feedback text
- **plot-*.png** - 4 visualization charts

---

## 🎨 Professional Features

✨ Your system includes:

- **Beautiful hero section** with gradient background (matches ynmodata.com design)
- **Expert information form** collecting demographics
- **Dynamic rating table** for all 630 items (quality 1-5, clarity 1-5)
- **Optional comments** field for each item
- **Form validation** (required fields, email checking)
- **Loading indicator** during submission
- **Success messages** confirming data saved
- **Responsive design** works on phone/tablet/laptop
- **Automatic data persistence** to CSV files
- **JSON backups** of each submission

---

## 🔗 Share URL with Experts

After deployment, share this URL:

```
https://[your-site-name].netlify.app
```

Example:
```
https://asq3-saudi-dashboard.netlify.app
```

Experts can access from any device, any time.

---

## 📈 Expected Timeline

| When | What |
|------|------|
| **Today** | ✅ System built & tested |
| **This week** | Deploy to Netlify (15 min) |
| **Next week** | Send to 3-5 test experts |
| **Following week** | Collect feedback, make adjustments |
| **Month 2** | Send to full expert panel (30-50 experts) |
| **Month 3** | Analyze all responses, prepare report |
| **Month 4** | Present findings to research team/IRB |

---

## ❓ Common Questions

### Q: Can experts save progress and come back later?
**A:** Not yet - they need to complete all items in one session. Future enhancement: add "save draft" feature.

### Q: How do I add more experts?
**A:** Just share the URL. No limit on number of experts. Each submission auto-saves.

### Q: Can I edit the item text?
**A:** Yes! Edit `R/data_setup.R` to change item translations, then run `quarto render .` to regenerate.

### Q: Is my data secure?
**A:** Data is stored as CSV files in your repository (not encrypted). For sensitive data with privacy requirements, move to encrypted database (see README-EXPERT-REVIEW.md security section).

### Q: What if Netlify Functions fail?
**A:** Form includes fallback to localStorage - data saves locally on browser and user can try again later.

---

## 🆘 Troubleshooting

### Form won't submit
- Check browser console (F12 → Console tab) for errors
- Ensure all required fields are filled
- Verify Netlify Functions deployed (check https://app.netlify.com → Functions)

### Data not saving
- Check netlify/functions logs in Netlify dashboard
- Verify `/data/evaluations/` directory exists locally
- Try submitting test data from your laptop

### Build fails on Netlify
- Check build logs in Netlify dashboard
- Verify `quarto render .` works locally first
- Common fix: Restart Netlify build (click "Clear cache and redeploy")

### Need help?
- **Deployment issues**: See DEPLOYMENT-GUIDE.md
- **Data structure**: See README-EXPERT-REVIEW.md
- **Implemented features**: See IMPLEMENTATION-CHECKLIST.md

---

## 📝 Next Steps (Right Now!)

1. **Read** DEPLOYMENT-GUIDE.md (5 min read)
2. **Create** GitHub account if needed (2 min)
3. **Push** code to GitHub (5 min)
4. **Deploy** on Netlify (5 min)
5. **Test** with sample submission (2 min)
6. **Share** URL with test experts

**Total**: ~20 minutes to live production system!

---

## 🎉 You're All Set!

Your ASQ-3 Saudi expert review system is:
- ✅ Fully built
- ✅ Professionally designed
- ✅ Data-collection ready
- ✅ Analysis-ready

**Ready to launch!** Follow DEPLOYMENT-GUIDE.md to get live. 🚀

---

**Questions?** Check the documentation files first, they have detailed answers and code examples!
