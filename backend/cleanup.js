/**
 * CLEANUP SCRIPT - Remove all unverified users from database
 * 
 * ⚠️  RUN THIS ONCE to clean up legacy unverified users created before the
 *     registration workflow was merged into the User collection.
 * 
 * Usage:
 * node cleanup.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/User');

async function cleanup() {
  try {
    console.log('Connecting to MongoDB...');
    const MONGO_URI = process.env.MONGODB_URI || process.env.MONGO_URI || 'mongodb://localhost:27017/bustrack_university';
    
    await mongoose.connect(MONGO_URI);
    console.log('✅ Connected to MongoDB');

    // Delete legacy unverified users only; active pending signups keep a
    // verification code and expiry in the User collection.
    const result = await User.deleteMany({
      emailVerified: false,
      $or: [
        { verificationCode: null },
        { verificationCode: { $exists: false } },
        { verificationExpiry: null },
        { verificationExpiry: { $exists: false } },
      ],
    });
    console.log(`\n🗑️  Deleted ${result.deletedCount} legacy unverified user(s) from User collection`);

    console.log('\n✅ Cleanup completed!');
    console.log('\nNOTE: Moving forward:');
    console.log('- Pending registrations now live in the User collection');
    console.log('- Verification codes expire after 10 minutes');
    console.log('- Re-registering the same email replaces the previous pending attempt');
    
  } catch (err) {
    console.error('❌ Cleanup error:', err.message);
  } finally {
    await mongoose.disconnect();
    process.exit(0);
  }
}

cleanup();
