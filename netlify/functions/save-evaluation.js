const fs = require('fs');
const path = require('path');
const { parse } = require('json2csv');

// Directory to store evaluations
const DATA_DIR = path.join(__dirname, '../../data/evaluations');

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

exports.handler = async (event) => {
  // Only allow POST requests
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      body: JSON.stringify({ message: 'Method not allowed' })
    };
  }

  try {
    const data = JSON.parse(event.body);

    // Validate required expert information
    if (!data.expert || !data.expert.fullName || !data.expert.email) {
      return {
        statusCode: 400,
        body: JSON.stringify({ message: 'Missing required expert information' })
      };
    }

    if (!data.evaluations || !Array.isArray(data.evaluations)) {
      return {
        statusCode: 400,
        body: JSON.stringify({ message: 'Invalid evaluations data' })
      };
    }

    // Create timestamp
    const timestamp = new Date().toISOString();

    // Save expert information to CSV
    const expertFile = path.join(DATA_DIR, 'experts.csv');
    const expertData = {
      timestamp,
      fullName: data.expert.fullName,
      email: data.expert.email,
      institution: data.expert.institution || '',
      expertise: data.expert.expertise,
      yearsExperience: data.expert.yearsExperience,
      language: data.expert.language,
      additionalInfo: data.expert.additionalInfo || ''
    };

    appendToCSV(expertFile, [expertData]);

    // Save item ratings to CSV
    const ratingsFile = path.join(DATA_DIR, 'item-ratings.csv');
    const ratings = data.evaluations.map(eval => ({
      timestamp,
      expertEmail: data.expert.email,
      expertName: data.expert.fullName,
      itemIndex: eval.itemIndex,
      quality: eval.quality || '',
      clarity: eval.clarity || '',
      comment: eval.comment || ''
    }));

    appendToCSV(ratingsFile, ratings);

    // Save raw JSON for backup
    const jsonFile = path.join(DATA_DIR, `evaluation-${timestamp.replace(/[:.]/g, '-')}.json`);
    fs.writeFileSync(jsonFile, JSON.stringify({ timestamp, ...data }, null, 2));

    console.log(`Evaluation saved for expert: ${data.expert.fullName}`);

    return {
      statusCode: 200,
      body: JSON.stringify({ 
        message: 'Evaluation saved successfully',
        timestamp
      })
    };
  } catch (error) {
    console.error('Error saving evaluation:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error saving evaluation: ' + error.message })
    };
  }
};

function appendToCSV(filePath, records) {
  try {
    let csv;
    let fileExists = fs.existsSync(filePath);

    if (!records || records.length === 0) return;

    // Convert records to CSV
    csv = parse(records, {
      header: !fileExists,
      newline: '\n'
    });

    // Append to file
    if (fileExists) {
      fs.appendFileSync(filePath, csv + '\n');
    } else {
      fs.writeFileSync(filePath, csv + '\n');
    }
  } catch (error) {
    console.error(`Error appending to ${filePath}:`, error);
    throw error;
  }
}
