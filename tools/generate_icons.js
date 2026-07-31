const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const SVG_PATH = path.join(__dirname, 'app_icon.svg');
const PROJECT_ROOT = path.join(__dirname, '..', 'sing_sprout');

// Android mipmap directories and their target sizes
const ANDROID_ICONS = [
  { dir: 'android/app/src/main/res/mipmap-mdpi',    size: 48 },
  { dir: 'android/app/src/main/res/mipmap-hdpi',    size: 72 },
  { dir: 'android/app/src/main/res/mipmap-xhdpi',   size: 96 },
  { dir: 'android/app/src/main/res/mipmap-xxhdpi',  size: 144 },
  { dir: 'android/app/src/main/res/mipmap-xxxhdpi', size: 192 },
];

// Web icons
const WEB_ICONS = [
  { file: 'web/favicon.png',               size: 16 },
  { file: 'web/icons/Icon-192.png',        size: 192 },
  { file: 'web/icons/Icon-512.png',        size: 512 },
  { file: 'web/icons/Icon-maskable-192.png', size: 192 },
  { file: 'web/icons/Icon-maskable-512.png', size: 512 },
];

// Play Store requires 512x512
const PLAY_STORE_ICON = { dir: 'android', file: 'ic_launcher-playstore.png', size: 512 };

// Also generate a 1024x1024 master PNG for reference
const MASTER_PNG = path.join(__dirname, 'app_icon_master.png');

async function generateIcon(size, outputPath) {
  const dir = path.dirname(outputPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  await sharp(SVG_PATH)
    .resize(size, size)
    .png()
    .toFile(outputPath);

  console.log(`  ✓ ${size}x${size} → ${outputPath}`);
}

async function main() {
  console.log('🎨 Generating app icons from SVG...\n');

  // Read SVG
  const svgBuffer = fs.readFileSync(SVG_PATH);
  console.log(`  Source: ${SVG_PATH}\n`);

  // Generate master PNG (1024x1024)
  console.log('📦 Master PNG:');
  await generateIcon(1024, MASTER_PNG);

  // Generate Android launcher icons
  console.log('\n📱 Android launcher icons:');
  for (const { dir, size } of ANDROID_ICONS) {
    const fullPath = path.join(PROJECT_ROOT, dir, 'ic_launcher.png');
    await generateIcon(size, fullPath);
  }

  // Generate Play Store icon
  console.log('\n🏪 Play Store icon:');
  const playStorePath = path.join(PROJECT_ROOT, PLAY_STORE_ICON.dir, PLAY_STORE_ICON.file);
  await generateIcon(PLAY_STORE_ICON.size, playStorePath);

  // Generate Web icons
  console.log('\n🌐 Web icons:');
  for (const { file, size } of WEB_ICONS) {
    const fullPath = path.join(PROJECT_ROOT, file);
    await generateIcon(size, fullPath);
  }

  console.log('\n✅ All icons generated successfully!');
  console.log(`\n   Master SVG:  ${SVG_PATH}`);
  console.log(`   Master PNG:  ${MASTER_PNG}`);
}

main().catch(err => {
  console.error('❌ Error:', err.message);
  process.exit(1);
});
