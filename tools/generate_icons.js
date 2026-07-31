const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const SVG_PATH = path.join(__dirname, 'app_icon.svg');
const SVG_FOREGROUND_PATH = path.join(__dirname, 'app_icon_foreground.svg');
const PROJECT_ROOT = path.join(__dirname, '..', 'sing_sprout');

// Android mipmap directories and their target sizes (legacy launcher icons)
const ANDROID_ICONS = [
  { dir: 'android/app/src/main/res/mipmap-mdpi',    size: 48 },
  { dir: 'android/app/src/main/res/mipmap-hdpi',    size: 72 },
  { dir: 'android/app/src/main/res/mipmap-xhdpi',   size: 96 },
  { dir: 'android/app/src/main/res/mipmap-xxhdpi',  size: 144 },
  { dir: 'android/app/src/main/res/mipmap-xxxhdpi', size: 192 },
];

// Android adaptive icon foreground layers (108dp canvas at each density)
// Safe zone is the inner 66.67% (72dp), artwork should be centered within
const ADAPTIVE_FOREGROUND_ICONS = [
  { dir: 'android/app/src/main/res/mipmap-mdpi',    size: 108 },
  { dir: 'android/app/src/main/res/mipmap-hdpi',    size: 162 },
  { dir: 'android/app/src/main/res/mipmap-xhdpi',   size: 216 },
  { dir: 'android/app/src/main/res/mipmap-xxhdpi',  size: 324 },
  { dir: 'android/app/src/main/res/mipmap-xxxhdpi', size: 432 },
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

async function generateIcon(size, outputPath, svgPath) {
  const dir = path.dirname(outputPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const src = svgPath || SVG_PATH;
  await sharp(src)
    .resize(size, size)
    .png()
    .toFile(outputPath);

  console.log(`  ✓ ${size}x${size} → ${outputPath}`);
}

async function main() {
  console.log('🎨 Generating app icons from SVG...\n');

  // Read SVG
  console.log(`  Source (full):  ${SVG_PATH}`);
  console.log(`  Source (fg):    ${SVG_FOREGROUND_PATH}\n`);

  // Generate master PNG (1024x1024)
  console.log('📦 Master PNG:');
  await generateIcon(1024, MASTER_PNG);

  // Generate Android launcher icons (legacy — full icon with baked background)
  console.log('\n📱 Android launcher icons (legacy):');
  for (const { dir, size } of ANDROID_ICONS) {
    const fullPath = path.join(PROJECT_ROOT, dir, 'ic_launcher.png');
    await generateIcon(size, fullPath);
  }

  // Generate Android adaptive icon foreground layers (transparent background)
  console.log('\n🔄 Android adaptive icon foregrounds (108dp):');
  for (const { dir, size } of ADAPTIVE_FOREGROUND_ICONS) {
    const fullPath = path.join(PROJECT_ROOT, dir, 'ic_launcher_foreground.png');
    await generateIcon(size, fullPath, SVG_FOREGROUND_PATH);
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
  console.log(`\n   Master SVG:       ${SVG_PATH}`);
  console.log(`   Foreground SVG:   ${SVG_FOREGROUND_PATH}`);
  console.log(`   Master PNG:       ${MASTER_PNG}`);
  console.log('\n   Android launcher icons:     ic_launcher.png (legacy, 48-192px)');
  console.log('   Android adaptive fg icons:  ic_launcher_foreground.png (108-432px)');
  console.log('   Adaptive icon config:       mipmap-anydpi-v26/ic_launcher.xml');
}

main().catch(err => {
  console.error('❌ Error:', err.message);
  process.exit(1);
});
