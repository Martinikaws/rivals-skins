const fs = require('fs');
const https = require('https');
const path = require('path');
const { execSync } = require('child_process');

const url = "https://raw.githubusercontent.com/Martinikaws/ItemLibrary-rivals.09-01-26/refs/heads/main/Items.lua";

function fetch(url) {
    return new Promise((resolve, reject) => {
        https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } }, res => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => resolve(data));
        }).on('error', reject);
    });
}

// Temporarily disabled skins undergoing model rig fixes
const DISABLED_SKINS = [
    "Crystal Daggers",
    "Mega Drill",
    "Spider Ray",
    "Hand Gun",
    "Armature.001",
    "Arch Molotov",
    "Pizza Box",
    "Arch Crossbow",
    "Keyblade",
    "Shotkey",
    "Palm Scythe",
    "Festive Fists",
    "Keyvolver"
];

const WEAPON_ICONS_DEFAULT = {
    "Assault Rifle": "🔫",
    "Burst Rifle": "🔫",
    "Sniper": "🎯",
    "Shotgun": "💥",
    "Minigun": "🔥",
    "Energy Rifle": "⚡",
    "Exogun": "🛸",
    "Flamethrower": "🔥",
    "Paintball Gun": "🎨",
    "Bow": "🏹",
    "Uzi": "🔫",
    "Energy Pistols": "⚡",
    "Handgun": "🔫",
    "Revolver": "🤠",
    "Shorty": "💥",
    "Spray": "💨",
    "Flare Gun": "✨",
    "Slingshot": "🎯",
    "Crossbow": "🏹",
    "Katana": "⚔️",
    "Gunblade": "⚔️",
    "Knife": "🔪",
    "Daggers": "🗡️",
    "Scythe": "🌾",
    "Chainsaw": "🪚",
    "Battle Axe": "🪓",
    "Fists": "🥊",
    "Spear": "🔱",
    "Maul": "🔨",
    "Flashbang": "💡",
    "Molotov": "🍾",
    "Smoke Grenade": "💨",
    "Satchel": "💣",
    "Freeze Ray": "❄️",
    "Jump Pad": "🚀",
    "Medkit": "🩹",
    "War Horn": "📯",
    "Subspace Tripmine": "💠",
    "Warper": "🌀",
    "Distortion": "🌌",
    "Warpstone": "💎",
    "RPG": "🚀",
    "Grenade": "💣",
    "Grenade Launcher": "💣",
    "Riot Shield": "🛡️",
    "Permafrost": "❄️",
    "Trowel": "🧱",
    "Grappler": "🪝"
};

async function main() {
    console.log("Fetching latest Items.lua...");
    const content = await fetch(url);

    const weaponRegex = /\["([^"]+)"\]\s*=\s*\{([\s\S]*?)\n\s*\},/g;
    let match;
    const allWeapons = [];

    while ((match = weaponRegex.exec(content)) !== null) {
        const weaponName = match[1];
        const block = match[2];
        const skinRegex = /Name\s*=\s*"([^"]+)"/g;
        let skinMatch;
        const skins = [];

        while ((skinMatch = skinRegex.exec(block)) !== null) {
            const sName = skinMatch[1];
            if (!skins.includes(sName)) {
                skins.push(sName);
            }
        }

        const formattedSkins = ["Default"];
        for (const s of skins) {
            if (s !== "Standard" && s !== "Default" && !formattedSkins.includes(s)) {
                if (!DISABLED_SKINS.includes(s)) {
                    formattedSkins.push(s);
                }
            }
        }

        const icon = WEAPON_ICONS_DEFAULT[weaponName] || "⚔️";

        allWeapons.push({
            name: weaponName,
            icon: icon,
            skins: formattedSkins
        });
    }

    // Sort alphabetically A-Z
    allWeapons.sort((a, b) => a.name.localeCompare(b.name));

    console.log(`Parsed ${allWeapons.length} weapons sorted alphabetically A-Z.`);

    const indexPath = path.join(__dirname, 'index.html');
    let html = fs.readFileSync(indexPath, 'utf-8');

    // Replace OFFICIAL_WEAPON_DATA
    const startStr = 'const OFFICIAL_WEAPON_DATA = ';
    const endStr = ';\n\n        function getSkinVisual';

    const startIdx = html.indexOf(startStr);
    const endIdx = html.indexOf(endStr, startIdx);

    if (startIdx === -1 || endIdx === -1) {
        console.error("Failed to find boundaries in index.html!");
        process.exit(1);
    }

    html = html.substring(0, startIdx + startStr.length) + JSON.stringify(allWeapons, null, 12) + html.substring(endIdx);

    // Remove category filters HTML block if present
    html = html.replace(/<div class="category-filters">[\s\S]*?<\/div>\s*<\/div>/g, '');
    html = html.replace(/<div class="category-filters">[\s\S]*?<\/div>/g, '');
    
    // Remove category tag from card-header
    html = html.replace(/<span class="category-tag">[\s\S]*?<\/span>/g, '');

    // Simplify filterWeapons to only search query
    const filterFnOld = `function filterWeapons() {
            const query = document.getElementById("searchInput").value.toLowerCase();
            const cards = document.querySelectorAll(".weapon-card");

            cards.forEach(card => {
                const wName = card.dataset.name;
                const cat = card.dataset.category;
                const matchSearch = wName.includes(query);
                const matchCategory = (activeCategory === "all" || cat === activeCategory);

                card.style.display = (matchSearch && matchCategory) ? "flex" : "none";
            });
        }`;

    const filterFnNew = `function filterWeapons() {
            const query = document.getElementById("searchInput").value.toLowerCase();
            const cards = document.querySelectorAll(".weapon-card");

            cards.forEach(card => {
                const wName = card.dataset.name;
                const matchSearch = wName.includes(query);
                card.style.display = matchSearch ? "flex" : "none";
            });
        }`;

    if (html.includes(filterFnOld)) {
        html = html.replace(filterFnOld, filterFnNew);
    }

    fs.writeFileSync(indexPath, html, 'utf-8');
    console.log("Updated index.html successfully without categories!");

    console.log("Committing and pushing to GitHub...");
    execSync('git add index.html sync_full_items.js', { cwd: __dirname });
    execSync('git commit -m "Remove categories for a unified alphabetical weapon list"', { cwd: __dirname });
    execSync('git push origin main', { cwd: __dirname });
    console.log("Pushed to GitHub main branch!");
}

main().catch(console.error);
