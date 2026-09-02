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

const CATEGORY_MAP = {
    "Assault Rifle": "Primary",
    "Burst Rifle": "Primary",
    "Sniper": "Primary",
    "Shotgun": "Primary",
    "Minigun": "Primary",
    "Energy Rifle": "Primary",
    "Exogun": "Primary",
    "Flamethrower": "Primary",
    "Paintball Gun": "Primary",
    "Bow": "Primary",
    "Uzi": "Secondary",
    "Energy Pistols": "Secondary",
    "Handgun": "Secondary",
    "Revolver": "Secondary",
    "Shorty": "Secondary",
    "Spray": "Secondary",
    "Flare Gun": "Secondary",
    "Slingshot": "Secondary",
    "Crossbow": "Secondary",
    "Katana": "Melee",
    "Gunblade": "Melee",
    "Knife": "Melee",
    "Daggers": "Melee",
    "Scythe": "Melee",
    "Chainsaw": "Melee",
    "Battle Axe": "Melee",
    "Fists": "Melee",
    "Spear": "Melee",
    "Maul": "Melee",
    "Flashbang": "Utility",
    "Molotov": "Utility",
    "Smoke Grenade": "Utility",
    "Satchel": "Utility",
    "Freeze Ray": "Utility",
    "Jump Pad": "Utility",
    "Medkit": "Utility",
    "War Horn": "Utility",
    "Subspace Tripmine": "Utility",
    "Warper": "Utility",
    "Distortion": "Utility",
    "Warpstone": "Utility",
    "RPG": "Utility",
    "Grenade": "Utility",
    "Grenade Launcher": "Utility",
    "Riot Shield": "Special",
    "Permafrost": "Special",
    "Trowel": "Special",
    "Grappler": "Special"
};

const ICONS_MAP = {
    "Primary": "🔫",
    "Secondary": "⚡",
    "Melee": "⚔️",
    "Utility": "💣",
    "Special": "🛡️"
};

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

        const category = CATEGORY_MAP[weaponName] || "Utility";
        const icon = ICONS_MAP[category] || "⚔️";

        allWeapons.push({
            name: weaponName,
            category: category,
            icon: icon,
            skins: formattedSkins
        });
    }

    console.log(`Parsed ${allWeapons.length} weapons (temporarily filtered out ${DISABLED_SKINS.length} WIP skins)`);

    const catOrder = ["Primary", "Secondary", "Melee", "Utility", "Special"];
    allWeapons.sort((a, b) => {
        const catA = catOrder.indexOf(a.category);
        const catB = catOrder.indexOf(b.category);
        if (catA !== catB) return catA - catB;
        return a.name.localeCompare(b.name);
    });

    const indexPath = path.join(__dirname, 'index.html');
    let html = fs.readFileSync(indexPath, 'utf-8');

    const startStr = 'const OFFICIAL_WEAPON_DATA = ';
    const endStr = ';\n\n        function getSkinVisual';

    const startIdx = html.indexOf(startStr);
    const endIdx = html.indexOf(endStr, startIdx);

    if (startIdx === -1 || endIdx === -1) {
        console.error("Failed to find boundaries in index.html!");
        process.exit(1);
    }

    html = html.substring(0, startIdx + startStr.length) + JSON.stringify(allWeapons, null, 12) + html.substring(endIdx);
    fs.writeFileSync(indexPath, html, 'utf-8');
    console.log("Updated index.html successfully!");

    console.log("Committing and pushing to GitHub...");
    execSync('git add index.html sync_full_items.js', { cwd: __dirname });
    execSync('git commit -m "Temporarily filter out 13 WIP skins from web configurator"', { cwd: __dirname });
    execSync('git push origin main', { cwd: __dirname });
    console.log("Pushed to GitHub main branch!");
}

main().catch(console.error);
