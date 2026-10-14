// scripts/generate_silent_hill_town.mjs
// Generates a comprehensive, high-fidelity Silent Hill inspired abandoned town model
// in standard Roblox XML (.rbxmx) format for Roblox Studio and Rojo.

import fs from 'fs';
import path from 'path';

let refCounter = 0;
function nextRef() {
  return `RBX_${refCounter++}`;
}

function escapeXml(unsafe) {
  return unsafe.replace(/[<>&'"]/g, (c) => {
    switch (c) {
      case '<': return '&lt;';
      case '>': return '&gt;';
      case '&': return '&amp;';
      case '\'': return '&apos;';
      case '"': return '&quot;';
    }
  });
}

function cframe(x, y, z, yawDeg = 0, pitchDeg = 0, rollDeg = 0) {
  const yaw = (yawDeg * Math.PI) / 180;
  const pitch = (pitchDeg * Math.PI) / 180;
  const roll = (rollDeg * Math.PI) / 180;

  const cy = Math.cos(yaw), sy = Math.sin(yaw);
  const cp = Math.cos(pitch), sp = Math.sin(pitch);
  const cr = Math.cos(roll), sr = Math.sin(roll);

  // Standard Rx * Ry * Rz matrix
  const r00 = cy * cr + sy * sp * sr;
  const r01 = -cy * sr + sy * sp * cr;
  const r02 = sy * cp;

  const r10 = cp * sr;
  const r11 = cp * cr;
  const r12 = -sp;

  const r20 = -sy * cr + cy * sp * sr;
  const r21 = sy * sr + cy * sp * cr;
  const r22 = cy * cp;

  return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 };
}

// Transform a local offset (lx, ly, lz) and yaw rotation by parent's world position and yaw
function transformOffset(parentX, parentY, parentZ, parentYaw, lx, ly, lz, localYaw = 0, pitch = 0, roll = 0) {
  const rad = (parentYaw * Math.PI) / 180;
  const cos = Math.cos(rad);
  const sin = Math.sin(rad);

  const wx = parentX + lx * cos + lz * sin;
  const wy = parentY + ly;
  const wz = parentZ - lx * sin + lz * cos;
  const totalYaw = (parentYaw + localYaw) % 360;

  return cframe(wx, wy, wz, totalYaw, pitch, roll);
}

const MAT = {
  Plastic: 256,
  SmoothPlastic: 272,
  Neon: 288,
  Wood: 512,
  WoodPlanks: 528,
  Concrete: 784,
  Brick: 816,
  CorrodedMetal: 1040,
  DiamondPlate: 1056,
  Metal: 1072,
  Grass: 1280,
  Glass: 1568,
};

function renderItem(className, name, props, children = []) {
  const ref = nextRef();
  let xml = `  <Item class="${className}" referent="${ref}">\n    <Properties>\n      <string name="Name">${escapeXml(name)}</string>\n`;

  for (const [k, v] of Object.entries(props)) {
    if (k === 'size') {
      xml += `      <Vector3 name="size"><X>${v[0]}</X><Y>${v[1]}</Y><Z>${v[2]}</Z></Vector3>\n`;
    } else if (k === 'cframe') {
      xml += `      <CoordinateFrame name="CFrame">\n`;
      xml += `        <X>${v.x}</X><Y>${v.y}</Y><Z>${v.z}</Z>\n`;
      xml += `        <R00>${v.r00.toFixed(6)}</R00><R01>${v.r01.toFixed(6)}</R01><R02>${v.r02.toFixed(6)}</R02>\n`;
      xml += `        <R10>${v.r10.toFixed(6)}</R10><R11>${v.r11.toFixed(6)}</R11><R12>${v.r12.toFixed(6)}</R12>\n`;
      xml += `        <R20>${v.r20.toFixed(6)}</R20><R21>${v.r21.toFixed(6)}</R21><R22>${v.r22.toFixed(6)}</R22>\n`;
      xml += `      </CoordinateFrame>\n`;
    } else if (k === 'color') {
      xml += `      <Color3 name="Color"><R>${v[0]}</R><G>${v[1]}</G><B>${v[2]}</B></Color3>\n`;
    } else if (k === 'material') {
      xml += `      <token name="Material">${v}</token>\n`;
    } else if (k === 'shape') {
      xml += `      <token name="shape">${v}</token>\n`;
    } else if (typeof v === 'boolean') {
      xml += `      <bool name="${k}">${v}</bool>\n`;
    } else if (typeof v === 'number') {
      if (Number.isInteger(v)) {
        xml += `      <int name="${k}">${v}</int>\n`;
      } else {
        xml += `      <float name="${k}">${v}</float>\n`;
      }
    } else if (typeof v === 'string') {
      xml += `      <string name="${k}">${escapeXml(v)}</string>\n`;
    }
  }

  xml += `    </Properties>\n`;
  for (const child of children) {
    xml += child;
  }
  xml += `  </Item>\n`;
  return xml;
}

function makePart({
  name = 'Part',
  className = 'Part',
  cf,
  size = [4, 1, 4],
  color = [0.5, 0.5, 0.5],
  material = MAT.SmoothPlastic,
  transparency = 0,
  reflectance = 0,
  anchored = true,
  canCollide = true,
  shape = null,
  children = [],
}) {
  const props = {
    cframe: cf,
    size,
    color,
    material,
    Anchored: anchored,
    CanCollide: canCollide,
  };
  if (transparency > 0) props.Transparency = transparency;
  if (reflectance > 0) props.Reflectance = reflectance;
  if (shape !== null) props.shape = shape;

  return renderItem(className, name, props, children);
}

function makePointLight({ name = 'Light', color = [1, 0.95, 0.8], brightness = 2.5, range = 30, shadows = true }) {
  const ref = nextRef();
  return `    <Item class="PointLight" referent="${ref}">
      <Properties>
        <string name="Name">${escapeXml(name)}</string>
        <Color3 name="Color"><R>${color[0]}</R><G>${color[1]}</G><B>${color[2]}</B></Color3>
        <float name="Brightness">${brightness}</float>
        <float name="Range">${range}</float>
        <bool name="Shadows">${shadows}</bool>
      </Properties>
    </Item>\n`;
}

function makeModel(name, children = []) {
  const ref = nextRef();
  let xml = `  <Item class="Model" referent="${ref}">\n    <Properties>\n      <string name="Name">${escapeXml(name)}</string>\n    </Properties>\n`;
  for (const child of children) {
    xml += child;
  }
  xml += `  </Item>\n`;
  return xml;
}

// -------------------------------------------------------------
// BUILDERS FOR DISTINCT SILENT HILL ASSETS
// -------------------------------------------------------------

function buildVintageLamppost(x, y, z) {
  const parts = [];
  // Cast iron pedestal
  parts.push(makePart({
    name: 'BasePlinth',
    cf: cframe(x, y + 1.2, z),
    size: [2.2, 2.4, 2.2],
    color: [0.22, 0.25, 0.24],
    material: MAT.Metal,
  }));
  // Vertical tapered mast
  parts.push(makePart({
    name: 'Mast',
    cf: cframe(x, y + 8.5, z),
    size: [1.2, 12, 1.2],
    color: [0.20, 0.23, 0.22],
    material: MAT.Metal,
  }));
  // Ornate arched cross-arm
  parts.push(makePart({
    name: 'CrossArm',
    cf: cframe(x, y + 15, z),
    size: [4.2, 0.8, 1.0],
    color: [0.18, 0.21, 0.20],
    material: MAT.Metal,
  }));
  // Glass lantern housing with warm glowing light
  const lightItem = makePointLight({
    name: 'LanternLight',
    color: [1.0, 0.92, 0.75],
    brightness: 3.2,
    range: 36,
    shadows: true,
  });
  parts.push(makePart({
    name: 'LanternHead',
    cf: cframe(x - 1.6, y + 14.2, z),
    size: [1.4, 2.2, 1.4],
    color: [1.0, 0.95, 0.80],
    material: MAT.Neon,
    children: [lightItem],
  }));
  // Cap
  parts.push(makePart({
    name: 'LanternCap',
    cf: cframe(x - 1.6, y + 15.6, z),
    size: [1.8, 0.6, 1.8],
    color: [0.18, 0.20, 0.19],
    material: MAT.Metal,
  }));

  return makeModel('VintageLamppost', parts);
}

function buildUtilityPole(x, y, z) {
  const parts = [];
  // Weathered wooden telephone pole
  parts.push(makePart({
    name: 'PoleWood',
    cf: cframe(x, y + 16, z),
    size: [1.6, 32, 1.6],
    color: [0.35, 0.26, 0.18],
    material: MAT.Wood,
  }));
  // Cross arms
  parts.push(makePart({
    name: 'CrossArmUpper',
    cf: cframe(x, y + 30, z),
    size: [8.5, 0.8, 0.8],
    color: [0.32, 0.24, 0.16],
    material: MAT.Wood,
  }));
  parts.push(makePart({
    name: 'CrossArmLower',
    cf: cframe(x, y + 26, z),
    size: [7.0, 0.8, 0.8],
    color: [0.32, 0.24, 0.16],
    material: MAT.Wood,
  }));
  // Insulators
  for (const dx of [-3.5, -1.8, 1.8, 3.5]) {
    parts.push(makePart({
      name: 'Insulator',
      cf: cframe(x + dx, y + 30.8, z),
      size: [0.6, 0.8, 0.6],
      color: [0.85, 0.88, 0.85],
      material: MAT.Glass,
    }));
  }
  // Heavy cylindrical pole transformer
  parts.push(makePart({
    name: 'Transformer',
    cf: cframe(x + 1.2, y + 23, z),
    size: [2.0, 4.0, 2.0],
    color: [0.28, 0.30, 0.32],
    material: MAT.Metal,
  }));

  return makeModel('UtilityPole', parts);
}

function buildAbandonedCar(x, y, z, yawDeg, type = 'Sedan') {
  const parts = [];
  const cf = (lx, ly, lz, lyaw = 0, lp = 0, lr = 0) => transformOffset(x, y, z, yawDeg, lx, ly, lz, lyaw, lp, lr);

  if (type === 'StationWagon') {
    // 1980s wood-paneled station wagon matching the reference image!
    // Lower Chassis
    parts.push(makePart({
      name: 'Chassis',
      cf: cf(0, 1.2, 0),
      size: [7.2, 1.6, 17],
      color: [0.22, 0.26, 0.30], // weathered midnight blue
      material: MAT.Metal,
      reflectance: 0.15,
    }));
    // Woodgrain side panels
    for (const side of [-1, 1]) {
      parts.push(makePart({
        name: 'WoodGrainPanel',
        cf: cf(side * 3.65, 1.8, 0),
        size: [0.2, 1.6, 13],
        color: [0.42, 0.26, 0.14],
        material: MAT.WoodPlanks,
      }));
    }
    // Cabin Greenhouse & Roof
    parts.push(makePart({
      name: 'Cabin',
      cf: cf(0, 3.1, -0.5),
      size: [6.6, 2.4, 11],
      color: [0.25, 0.30, 0.35],
      material: MAT.Metal,
    }));
    // Dark dusty glass
    parts.push(makePart({
      name: 'Windshield',
      cf: cf(0, 3.0, 5.2, 0, -22, 0),
      size: [6.2, 2.2, 0.3],
      color: [0.15, 0.18, 0.20],
      material: MAT.Glass,
      transparency: 0.35,
    }));
    // Wheels (flat, rusted)
    for (const wx of [-3.7, 3.7]) {
      for (const wz of [-5.5, 5.5]) {
        parts.push(makePart({
          name: 'Wheel',
          cf: cf(wx, 0.8, wz),
          size: [0.9, 2.4, 2.4],
          color: [0.12, 0.12, 0.12],
          material: MAT.SmoothPlastic,
        }));
      }
    }
  } else if (type === 'Pickup') {
    // Rusted Farm Pickup
    parts.push(makePart({
      name: 'Chassis',
      cf: cf(0, 1.4, 0),
      size: [7.4, 1.8, 16],
      color: [0.45, 0.22, 0.16], // Rusted oxide red
      material: MAT.CorrodedMetal,
    }));
    parts.push(makePart({
      name: 'Cab',
      cf: cf(0, 3.4, 2.5),
      size: [7.0, 2.8, 7.5],
      color: [0.48, 0.24, 0.18],
      material: MAT.CorrodedMetal,
    }));
    // Open truck bed with tailgate
    parts.push(makePart({
      name: 'TruckBedFloor',
      cf: cf(0, 1.8, -4.5),
      size: [6.8, 0.6, 7.5],
      color: [0.38, 0.20, 0.15],
      material: MAT.CorrodedMetal,
    }));
    for (const side of [-1, 1]) {
      parts.push(makePart({
        name: 'BedWall',
        cf: cf(side * 3.4, 2.7, -4.5),
        size: [0.4, 1.8, 7.5],
        color: [0.45, 0.22, 0.16],
        material: MAT.CorrodedMetal,
      }));
    }
    // Wheels
    for (const wx of [-3.8, 3.8]) {
      for (const wz of [-5.0, 5.0]) {
        parts.push(makePart({
          name: 'Wheel',
          cf: cf(wx, 0.9, wz),
          size: [1.1, 2.6, 2.6],
          color: [0.15, 0.15, 0.15],
          material: MAT.SmoothPlastic,
        }));
      }
    }
  } else {
    // 1970s Abandoned Sedan
    parts.push(makePart({
      name: 'Chassis',
      cf: cf(0, 1.2, 0),
      size: [7.2, 1.6, 16.5],
      color: [0.55, 0.52, 0.48], // weathered beige
      material: MAT.Metal,
      reflectance: 0.1,
    }));
    parts.push(makePart({
      name: 'Cabin',
      cf: cf(0, 3.0, 0),
      size: [6.6, 2.2, 8.5],
      color: [0.52, 0.50, 0.46],
      material: MAT.Metal,
    }));
    for (const wx of [-3.7, 3.7]) {
      for (const wz of [-5.2, 5.2]) {
        parts.push(makePart({
          name: 'Wheel',
          cf: cf(wx, 0.8, wz),
          size: [0.9, 2.4, 2.4],
          color: [0.12, 0.12, 0.12],
          material: MAT.SmoothPlastic,
        }));
      }
    }
  }

  return makeModel(`AbandonedVehicle_${type}`, parts);
}

// -------------------------------------------------------------
// ABANDONED HOUSE GENERATOR (6 AUTHENTIC SILENT HILL VARIANTS)
// -------------------------------------------------------------

const HOUSE_THEMES = [
  { name: 'WeatherboardColonial', wallColor: [0.76, 0.77, 0.75], wallMat: MAT.WoodPlanks, trim: [0.9, 0.9, 0.88], roofColor: [0.38, 0.40, 0.42] },
  { name: 'DustyBlueCraftsman', wallColor: [0.37, 0.45, 0.52], wallMat: MAT.WoodPlanks, trim: [0.85, 0.83, 0.78], roofColor: [0.28, 0.30, 0.32] },
  { name: 'DarkCedarBungalow', wallColor: [0.32, 0.24, 0.18], wallMat: MAT.WoodPlanks, trim: [0.24, 0.18, 0.14], roofColor: [0.35, 0.38, 0.40] },
  { name: 'DerelictRedBrick', wallColor: [0.55, 0.24, 0.20], wallMat: MAT.Brick, trim: [0.80, 0.78, 0.72], roofColor: [0.25, 0.27, 0.29] },
  { name: 'MossOliveCottage', wallColor: [0.42, 0.48, 0.38], wallMat: MAT.WoodPlanks, trim: [0.82, 0.82, 0.76], roofColor: [0.30, 0.32, 0.35] },
  { name: 'VictorianSlate', wallColor: [0.28, 0.30, 0.34], wallMat: MAT.WoodPlanks, trim: [0.72, 0.72, 0.70], roofColor: [0.20, 0.22, 0.24] },
];

function buildAbandonedHouse(x, y, z, yawDeg, styleIdx) {
  const theme = HOUSE_THEMES[styleIdx % HOUSE_THEMES.length];
  const parts = [];
  const cf = (lx, ly, lz, lyaw = 0, lp = 0, lr = 0) => transformOffset(x, y, z, yawDeg, lx, ly, lz, lyaw, lp, lr);

  // 1. Concrete Foundation Plinth
  parts.push(makePart({
    name: 'Foundation',
    cf: cf(0, 1.0, 0),
    size: [36, 2.0, 42],
    color: [0.48, 0.48, 0.46],
    material: MAT.Concrete,
  }));

  // 2. Main Two-Story House Body
  const houseH = 16;
  parts.push(makePart({
    name: 'HouseBody',
    cf: cf(0, 2.0 + houseH / 2, 0),
    size: [34, houseH, 40],
    color: theme.wallColor,
    material: theme.wallMat,
  }));

  // 3. Corner Trims for realistic architectural articulation
  for (const cx of [-17.1, 17.1]) {
    for (const cz of [-20.1, 20.1]) {
      parts.push(makePart({
        name: 'CornerTrim',
        cf: cf(cx, 2.0 + houseH / 2, cz),
        size: [0.6, houseH, 0.6],
        color: theme.trim,
        material: MAT.Wood,
      }));
    }
  }

  // 4. Covered Front Porch
  const porchZ = 24.5;
  // Deck
  parts.push(makePart({
    name: 'PorchDeck',
    cf: cf(0, 1.6, porchZ),
    size: [34, 1.2, 9],
    color: [0.35, 0.28, 0.22],
    material: MAT.WoodPlanks,
  }));

  // Front Porch Steps
  for (let s = 1; s <= 3; s++) {
    parts.push(makePart({
      name: `PorchStep_${s}`,
      cf: cf(0, 1.6 - s * 0.4, porchZ + 4.5 + s * 1.2),
      size: [10, 0.4, 1.4],
      color: [0.38, 0.30, 0.24],
      material: MAT.WoodPlanks,
    }));
  }

  // Porch Columns
  for (const px of [-15, -5, 5, 15]) {
    parts.push(makePart({
      name: 'PorchColumn',
      cf: cf(px, 7.2, porchZ + 3.8),
      size: [1.2, 10.5, 1.2],
      color: theme.trim,
      material: MAT.Wood,
    }));
  }

  // Porch Railing
  for (const rx of [-10, 10]) {
    parts.push(makePart({
      name: 'PorchRailingTop',
      cf: cf(rx, 4.2, porchZ + 3.8),
      size: [8.5, 0.5, 0.6],
      color: theme.trim,
      material: MAT.Wood,
    }));
    parts.push(makePart({
      name: 'PorchRailingBottom',
      cf: cf(rx, 2.5, porchZ + 3.8),
      size: [8.5, 0.4, 0.6],
      color: theme.trim,
      material: MAT.Wood,
    }));
  }

  // Porch Overhang Roof
  parts.push(makePart({
    name: 'PorchRoof',
    cf: cf(0, 13.0, porchZ, 0, -12, 0),
    size: [36, 1.0, 10.5],
    color: theme.roofColor,
    material: MAT.CorrodedMetal,
  }));

  // Hanging Porch Lantern with atmospheric PointLight
  const porchLight = makePointLight({
    name: 'PorchLanternLight',
    color: [1.0, 0.88, 0.65],
    brightness: 2.8,
    range: 30,
    shadows: true,
  });
  parts.push(makePart({
    name: 'PorchLantern',
    cf: cf(4.0, 9.5, 20.6),
    size: [0.9, 1.4, 0.9],
    color: [1.0, 0.92, 0.70],
    material: MAT.Neon,
    children: [porchLight],
  }));

  // 5. Front Door & Doorway Frame
  parts.push(makePart({
    name: 'FrontDoorFrame',
    cf: cf(0, 6.2, 20.15),
    size: [5.2, 8.8, 0.4],
    color: theme.trim,
    material: MAT.Wood,
  }));
  parts.push(makePart({
    name: 'FrontDoor',
    cf: cf(0, 6.0, 20.25),
    size: [4.4, 8.0, 0.3],
    color: [0.26, 0.18, 0.12],
    material: MAT.WoodPlanks,
  }));

  // 6. Boarded-up Windows with Criss-Crossed Planks
  const windowSpots = [
    { x: -9.5, y: 7.5, z: 20.2 },
    { x: 9.5, y: 7.5, z: 20.2 },
    { x: -9.5, y: 14.0, z: 20.2 },
    { x: 9.5, y: 14.0, z: 20.2 },
    { x: 0, y: 14.0, z: 20.2 },
  ];

  for (let wi = 0; wi < windowSpots.length; wi++) {
    const ws = windowSpots[wi];
    // Window Frame
    parts.push(makePart({
      name: `WindowFrame_${wi}`,
      cf: cf(ws.x, ws.y, ws.z),
      size: [4.8, 5.2, 0.3],
      color: theme.trim,
      material: MAT.Wood,
    }));
    // Window Pane (dark, dusty reflection)
    parts.push(makePart({
      name: `WindowGlass_${wi}`,
      cf: cf(ws.x, ws.y, ws.z + 0.1),
      size: [4.2, 4.6, 0.2],
      color: [0.15, 0.18, 0.22],
      material: MAT.Glass,
      reflectance: 0.2,
    }));
    // Weathered Boarded Planks
    for (const [pAngle, dy] of [[-18, -1.0], [15, 0.8], [0, 0.0]]) {
      parts.push(makePart({
        name: `WindowPlank_${wi}`,
        cf: cf(ws.x, ws.y + dy, ws.z + 0.3, 0, 0, pAngle),
        size: [5.6, 0.9, 0.3],
        color: [0.36, 0.26, 0.18],
        material: MAT.WoodPlanks,
      }));
    }
  }

  // 7. Pitched Shingled/Metal Roof Panels with Eaves
  const roofPeakY = 2.0 + houseH + 8.5;
  for (const side of [-1, 1]) {
    parts.push(makePart({
      name: `RoofPanel_${side < 0 ? 'Left' : 'Right'}`,
      cf: cf(side * 9.5, roofPeakY - 4.2, 0, 0, 0, -side * 30),
      size: [22, 1.2, 44],
      color: theme.roofColor,
      material: MAT.CorrodedMetal,
    }));
  }

  // Gable Walls (Upper Triangular End Walls)
  for (const gz of [-20, 20]) {
    for (const side of [-1, 1]) {
      parts.push(makePart({
        className: 'WedgePart',
        name: 'GableEnd',
        cf: cf(side * 8.5, roofPeakY - 4.2, gz, gz > 0 ? 90 : -90, 0, side > 0 ? 0 : 180),
        size: [1.2, 8.0, 17],
        color: theme.wallColor,
        material: theme.wallMat,
      }));
    }
  }

  // 8. Brick Chimney
  parts.push(makePart({
    name: 'BrickChimney',
    cf: cf(-12, 14, -8),
    size: [4.0, 24, 4.0],
    color: [0.55, 0.24, 0.20],
    material: MAT.Brick,
  }));
  parts.push(makePart({
    name: 'ChimneyCap',
    cf: cf(-12, 26.4, -8),
    size: [4.8, 0.8, 4.8],
    color: [0.45, 0.45, 0.42],
    material: MAT.Concrete,
  }));

  // 9. Front Walkway & Broken Picket Fence
  // Concrete Front Walkway
  parts.push(makePart({
    name: 'FrontWalkway',
    cf: cf(0, 0.15, porchZ + 12),
    size: [6.0, 0.3, 14],
    color: [0.58, 0.58, 0.55],
    material: MAT.Concrete,
  }));

  // Picket Fences along front perimeter
  for (let fx = -22; fx <= 22; fx += 3.8) {
    if (Math.abs(fx) > 4.5) { // gap for walkway gate
      const tilt = ((fx % 3) - 1) * 6; // slightly askew, weathered fence
      parts.push(makePart({
        name: 'PicketPost',
        cf: cf(fx, 2.2, porchZ + 18, 0, 0, tilt),
        size: [0.6, 4.2, 0.6],
        color: [0.78, 0.78, 0.75],
        material: MAT.Wood,
      }));
    }
  }

  return makeModel(`AbandonedHouse_${theme.name}`, parts);
}

// -------------------------------------------------------------
// COMMERCIAL STOREFRONTS ALONG MAIN STREET
// -------------------------------------------------------------

function buildStorefront(x, y, z, yawDeg, title, facadeColor, roofColor) {
  const parts = [];
  const cf = (lx, ly, lz, lyaw = 0, lp = 0, lr = 0) => transformOffset(x, y, z, yawDeg, lx, ly, lz, lyaw, lp, lr);

  const w = 34, h = 26, d = 30;

  // Main Store Structure
  parts.push(makePart({
    name: 'MainBuilding',
    cf: cf(0, h / 2, 0),
    size: [w, h, d],
    color: facadeColor,
    material: MAT.Brick,
  }));

  // Parapet Roof Cornice
  parts.push(makePart({
    name: 'ParapetCornice',
    cf: cf(0, h + 1.2, 0),
    size: [w + 2, 2.4, d + 2],
    color: roofColor,
    material: MAT.Concrete,
  }));

  // Commercial Storefront Overhang / Awning
  parts.push(makePart({
    name: 'StoreAwning',
    cf: cf(0, 11, d / 2 + 3.5, 0, 14, 0),
    size: [w + 1, 0.8, 8.0],
    color: roofColor,
    material: MAT.SmoothPlastic,
  }));

  // Large Picture Display Windows
  for (const side of [-1, 1]) {
    parts.push(makePart({
      name: 'DisplayWindow',
      cf: cf(side * 8.5, 5.5, d / 2 + 0.2),
      size: [10, 8.0, 0.4],
      color: [0.18, 0.22, 0.26],
      material: MAT.Glass,
      reflectance: 0.35,
    }));
  }

  // Recessed Front Entrance Doorway
  parts.push(makePart({
    name: 'EntranceDoor',
    cf: cf(0, 4.5, d / 2 + 0.1),
    size: [5.0, 9.0, 0.4],
    color: [0.25, 0.22, 0.20],
    material: MAT.WoodPlanks,
  }));

  // Vintage Lit Overhead Sign Board
  const signLight = makePointLight({
    name: 'SignLight',
    color: [1.0, 0.94, 0.78],
    brightness: 2.8,
    range: 32,
    shadows: true,
  });
  parts.push(makePart({
    name: 'StoreSign',
    cf: cf(0, 15, d / 2 + 0.8),
    size: [24, 4.5, 1.2],
    color: [0.18, 0.18, 0.20],
    material: MAT.SmoothPlastic,
    children: [signLight],
  }));

  return makeModel(`Storefront_${title.replace(/\s+/g, '_')}`, parts);
}

// -------------------------------------------------------------
// TOWN SQUARE GAZEBO, BUNKER & RESEARCH HQ
// -------------------------------------------------------------

function buildVictorianGazebo(x, y, z) {
  const parts = [];
  // Elevated Octagonal Deck (approximated with overlapping parts)
  parts.push(makePart({
    name: 'GazeboFloor',
    cf: cframe(x, y + 1.5, z),
    size: [24, 1.6, 24],
    color: [0.42, 0.35, 0.28],
    material: MAT.WoodPlanks,
  }));
  // Perimeter Pillars
  const rad = 10.5;
  for (let a = 0; a < 8; a++) {
    const angle = (a / 8) * Math.PI * 2;
    const px = x + Math.cos(angle) * rad;
    const pz = z + Math.sin(angle) * rad;
    parts.push(makePart({
      name: `GazeboPillar_${a}`,
      cf: cframe(px, y + 7.5, pz),
      size: [1.2, 11, 1.2],
      color: [0.85, 0.85, 0.82],
      material: MAT.Wood,
    }));
  }
  // Tiered Overhanging Roof
  parts.push(makePart({
    name: 'GazeboRoofBase',
    cf: cframe(x, y + 13.5, z),
    size: [26, 1.4, 26],
    color: [0.32, 0.35, 0.36],
    material: MAT.CorrodedMetal,
  }));
  parts.push(makePart({
    name: 'GazeboRoofCupola',
    cf: cframe(x, y + 15.5, z),
    size: [16, 2.8, 16],
    color: [0.28, 0.30, 0.32],
    material: MAT.CorrodedMetal,
  }));
  // Warm hanging center lantern
  const gazeboLight = makePointLight({
    name: 'GazeboCenterLight',
    color: [1.0, 0.90, 0.65],
    brightness: 3.5,
    range: 35,
    shadows: true,
  });
  parts.push(makePart({
    name: 'GazeboCenterLantern',
    cf: cframe(x, y + 12.0, z),
    size: [1.2, 1.8, 1.2],
    color: [1.0, 0.92, 0.70],
    material: MAT.Neon,
    children: [gazeboLight],
  }));

  return makeModel('VictorianGazebo', parts);
}

function buildUndergroundBunkerHatch(x, y, z) {
  const parts = [];
  // Raised Concrete Blast Collar
  parts.push(makePart({
    name: 'BunkerSurfaceCollar',
    cf: cframe(x, y + 1.75, z),
    size: [24, 3.5, 24],
    color: [0.35, 0.35, 0.36],
    material: MAT.Concrete,
  }));

  // Caution Corner Floodlights
  const corners = [
    [-11, -11],
    [11, -11],
    [-11, 11],
    [11, 11],
  ];
  for (let i = 0; i < corners.length; i++) {
    const [cx, cz] = corners[i];
    const light = makePointLight({
      name: `BunkerCautionLight_${i}`,
      color: [1.0, 0.75, 0.15],
      brightness: 4.5,
      range: 35,
      shadows: true,
    });
    parts.push(makePart({
      name: 'BunkerLightPost',
      cf: cframe(x + cx, y + 3.8, z + cz),
      size: [1.0, 2.4, 1.0],
      color: [1.0, 0.75, 0.10],
      material: MAT.Neon,
      children: [light],
    }));
  }

  // Tilted Yellow Steel Blast Hatch
  parts.push(makePart({
    name: 'BlastHatch',
    cf: cframe(x, y + 3.8, z, 0, 18, 0),
    size: [14, 1.2, 14],
    color: [0.95, 0.75, 0.10],
    material: MAT.DiamondPlate,
    canCollide: false,
  }));

  // Entrance Teleport Pad
  parts.push(makePart({
    name: 'EntrancePad',
    cf: cframe(x, y + 1.8, z),
    size: [12, 1.0, 12],
    color: [0.20, 0.85, 1.0],
    material: MAT.Neon,
    transparency: 0.5,
    canCollide: false,
  }));

  return makeModel('UndergroundStormBunkerEntrance', parts);
}

function buildResearchHQTrailer(x, y, z) {
  const parts = [];
  // Aluminum Trailer Body
  parts.push(makePart({
    name: 'ResearchHQ',
    cf: cframe(x, y, z),
    size: [28, 12, 18],
    color: [0.75, 0.77, 0.80],
    material: MAT.Metal,
  }));
  // Dark lower skirt
  parts.push(makePart({
    name: 'TrailerSkirt',
    cf: cframe(x, y - 4.9, z),
    size: [28.4, 2.2, 18.4],
    color: [0.18, 0.20, 0.22],
    material: MAT.Metal,
  }));
  // High-visibility Orange Hazard Stripe
  parts.push(makePart({
    name: 'HazardStripe',
    cf: cframe(x, y + 0.6, z),
    size: [28.3, 1.4, 18.3],
    color: [0.92, 0.48, 0.12],
    material: MAT.SmoothPlastic,
  }));
  // Radar Dish Mast
  parts.push(makePart({
    name: 'DishMast',
    cf: cframe(x, y + 10, z),
    size: [2.0, 10, 2.0],
    color: [0.40, 0.42, 0.44],
    material: MAT.Metal,
  }));
  // Flashing Red Aviation Beacon on top of radar mast
  const redBeaconLight = makePointLight({
    name: 'BeaconLight',
    color: [1.0, 0.15, 0.15],
    brightness: 4.5,
    range: 40,
    shadows: true,
  });
  parts.push(makePart({
    name: 'RadarWarningBeacon',
    cf: cframe(x, y + 15.5, z),
    size: [1.2, 1.4, 1.2],
    color: [1.0, 0.15, 0.15],
    material: MAT.Neon,
    children: [redBeaconLight],
  }));

  return makeModel('ResearchHQTrailer', parts);
}

// -------------------------------------------------------------
// MAIN COMPOSITION ENGINE
// -------------------------------------------------------------

function generateFullTownXml() {
  const townChildren = [];

  // =========================================================
  // 1. BASE TERRAIN / GROUND UNDERLAY
  // =========================================================
  townChildren.push(makePart({
    name: 'TownGroundUnderlay',
    cf: cframe(0, 0.5, 0),
    size: [700, 1.0, 700],
    color: [0.38, 0.45, 0.32], // Muted weathered dead grass/turf
    material: MAT.Grass,
  }));

  // =========================================================
  // 2. MAIN STREET (NORTH-SOUTH HIGHWAY ROUTE 73)
  // =========================================================
  const mainRoadLen = 680;
  // Roadway
  townChildren.push(makePart({
    name: 'MainStreetRoad',
    cf: cframe(0, 1.1, 0),
    size: [38, 1.2, mainRoadLen],
    color: [0.18, 0.19, 0.21],
    material: MAT.SmoothPlastic,
    reflectance: 0.32, // Signature Silent Hill wet reflective asphalt!
  }));

  // Double Yellow Dividing Centerlines
  for (const dx of [-1.0, 1.0]) {
    townChildren.push(makePart({
      name: 'MainRoadCenterline',
      cf: cframe(dx, 1.15, 0),
      size: [0.6, 1.25, mainRoadLen],
      color: [0.88, 0.72, 0.15],
      material: MAT.SmoothPlastic,
    }));
  }

  // Sidewalks & Curbs along Main Street
  for (const side of [-1, 1]) {
    // Concrete Curb
    townChildren.push(makePart({
      name: `MainCurb_${side < 0 ? 'W' : 'E'}`,
      cf: cframe(side * 19.5, 1.3, 0),
      size: [1.2, 1.8, mainRoadLen],
      color: [0.55, 0.55, 0.52],
      material: MAT.Concrete,
    }));
    // Concrete Sidewalk
    townChildren.push(makePart({
      name: `MainSidewalk_${side < 0 ? 'W' : 'E'}`,
      cf: cframe(side * 26, 1.2, 0),
      size: [14, 1.4, mainRoadLen],
      color: [0.62, 0.62, 0.60],
      material: MAT.Concrete,
    }));
  }

  // Vintage Cast-Iron Lampposts along Main Street
  for (let z = -280; z <= 280; z += 45) {
    for (const side of [-1, 1]) {
      townChildren.push(buildVintageLamppost(side * 20.5, 1.3, z));
    }
  }

  // Utility Poles along Main Street
  for (let z = -270; z <= 270; z += 65) {
    townChildren.push(buildUtilityPole(32, 1.3, z));
  }

  // =========================================================
  // 3. CROSS-STREETS (RESIDENTIAL STREETS)
  // =========================================================
  const crossStreets = [
    { name: 'PineStreet', z: -210 },
    { name: 'MapleStreet', z: -80 },
    { name: 'ElmStreet', z: 80 },
    { name: 'OakAvenue', z: 210 },
  ];

  for (const street of crossStreets) {
    // Road Asphalt
    townChildren.push(makePart({
      name: `${street.name}_Road`,
      cf: cframe(0, 1.12, street.z),
      size: [480, 1.2, 30],
      color: [0.19, 0.20, 0.22],
      material: MAT.SmoothPlastic,
      reflectance: 0.30,
    }));

    // White Dashed Centerline
    for (let x = -230; x <= 230; x += 18) {
      if (Math.abs(x) > 22) { // don't overlap Main Street
        townChildren.push(makePart({
          name: `${street.name}_CenterStripe`,
          cf: cframe(x, 1.14, street.z),
          size: [10, 0.05, 0.6],
          color: [0.92, 0.92, 0.90],
          material: MAT.SmoothPlastic,
        }));
      }
    }

    // Sidewalks & Curbs
    for (const side of [-1, 1]) {
      townChildren.push(makePart({
        name: `${street.name}_Sidewalk_${side < 0 ? 'N' : 'S'}`,
        cf: cframe(0, 1.2, street.z + side * 19.5),
        size: [480, 1.4, 9.0],
        color: [0.62, 0.62, 0.60],
        material: MAT.Concrete,
      }));
    }

    // Pedestrian Crosswalk Stripes at Intersection with Main Street
    for (const cz of [street.z - 17, street.z + 17]) {
      for (let x = -16; x <= 16; x += 3.8) {
        townChildren.push(makePart({
          name: 'CrosswalkStripe',
          cf: cframe(x, 1.25, cz),
          size: [2.2, 0.05, 8.0],
          color: [0.92, 0.92, 0.90],
          material: MAT.SmoothPlastic,
        }));
      }
    }

    // Vintage Lampposts along Cross-Streets
    for (const x of [-190, -130, -70, 70, 130, 190]) {
      townChildren.push(buildVintageLamppost(x, 1.3, street.z - 16));
    }
  }

  // =========================================================
  // 4. OVER 24 ABANDONED HOUSES LINING THE RESIDENTIAL STREETS
  // =========================================================
  let houseCount = 0;

  // Pine Street (Z = -210) Houses
  const houseXPositions = [-200, -135, -70, 70, 135, 200];

  // Pine Street North (Z = -250, facing south towards road)
  for (let i = 0; i < houseXPositions.length; i++) {
    townChildren.push(buildAbandonedHouse(houseXPositions[i], 1.0, -250, 180, houseCount++));
  }
  // Pine Street South (Z = -170, facing north towards road)
  for (let i = 0; i < houseXPositions.length; i++) {
    townChildren.push(buildAbandonedHouse(houseXPositions[i], 1.0, -170, 0, houseCount++));
  }

  // Maple Street (Z = -80) Houses
  // Maple Street North (Z = -120, facing south towards road)
  for (let i = 0; i < houseXPositions.length; i++) {
    townChildren.push(buildAbandonedHouse(houseXPositions[i], 1.0, -120, 180, houseCount++));
  }
  // Maple Street South (Z = -40, West and East wings, leaving center for square/bunker)
  for (const x of [-200, -135, 135, 200]) {
    townChildren.push(buildAbandonedHouse(x, 1.0, -40, 0, houseCount++));
  }

  // Elm Street (Z = +80) Houses
  // Elm Street North (Z = +40, West and East wings)
  for (const x of [-200, -135, 135, 200]) {
    townChildren.push(buildAbandonedHouse(x, 1.0, 40, 180, houseCount++));
  }
  // Elm Street South (Z = +120, facing north towards road)
  for (let i = 0; i < houseXPositions.length; i++) {
    townChildren.push(buildAbandonedHouse(houseXPositions[i], 1.0, 120, 0, houseCount++));
  }

  // Oak Avenue (Z = +210) Houses
  // Oak Avenue North (Z = +170, facing south towards road)
  for (let i = 0; i < houseXPositions.length; i++) {
    townChildren.push(buildAbandonedHouse(houseXPositions[i], 1.0, 170, 180, houseCount++));
  }
  // Oak Avenue South (Z = +250, facing north towards road)
  for (let i = 0; i < houseXPositions.length; i++) {
    townChildren.push(buildAbandonedHouse(houseXPositions[i], 1.0, 250, 0, houseCount++));
  }

  console.log(`[Town Generator] Generated ${houseCount} detailed abandoned houses across the residential grid!`);

  // =========================================================
  // 5. COMMERCIAL STOREFRONTS ALONG MAIN STREET
  // =========================================================
  // West Side of Main Street (facing East, yaw = 90)
  townChildren.push(buildStorefront(-48, 1.0, 35, 90, 'ASHWOOD DINER', [0.55, 0.18, 0.15], [0.90, 0.88, 0.82]));
  townChildren.push(buildStorefront(-48, 1.0, -35, 90, 'PHARMACY & SUNDRIES', [0.18, 0.38, 0.28], [0.85, 0.88, 0.85]));
  townChildren.push(buildStorefront(-48, 1.0, 145, 90, 'GRAND VALLEY HARDWARE & FEED', [0.45, 0.32, 0.20], [0.35, 0.35, 0.38]));
  townChildren.push(buildStorefront(-48, 1.0, -145, 90, 'TOWN HALL & MUNICIPAL POLICE', [0.35, 0.36, 0.38], [0.75, 0.75, 0.72]));

  // East Side of Main Street (facing West, yaw = -90)
  townChildren.push(buildStorefront(48, 1.0, 35, -90, 'SILENT PEAKS AUTO SERVICE', [0.30, 0.32, 0.35], [0.88, 0.55, 0.15]));
  townChildren.push(buildStorefront(48, 1.0, -35, -90, 'GENERAL DRY GOODS', [0.48, 0.25, 0.20], [0.88, 0.86, 0.80]));
  townChildren.push(buildStorefront(48, 1.0, 145, -90, 'POST OFFICE & TELEGRAPH', [0.22, 0.32, 0.48], [0.85, 0.88, 0.90]));
  townChildren.push(buildStorefront(48, 1.0, -145, -90, 'SINCLAIR GAS & MOTOR SERVICE', [0.50, 0.22, 0.18], [0.30, 0.30, 0.32]));

  // =========================================================
  // 6. TOWN SQUARE, GAZEBO & STORM BUNKER
  // =========================================================
  // Town Square Park Lawn (East side of Main Street at Z = 0)
  townChildren.push(makePart({
    name: 'TownSquareParkLawn',
    cf: cframe(48, 1.25, 0),
    size: [34, 1.2, 54],
    color: [0.32, 0.42, 0.28],
    material: MAT.Grass,
  }));

  // Victorian Gazebo in Town Square
  townChildren.push(buildVictorianGazebo(50, 1.3, 0));

  // Underground Storm Bunker Entrance located conveniently on the square lawn
  townChildren.push(buildUndergroundBunkerHatch(24, 1.3, 0));

  // Research HQ Trailer parked on the West curb at Z = 0
  townChildren.push(buildResearchHQTrailer(-32, 7.0, 0));

  // Dual Depot Floodlight Towers illuminating Main Street
  for (const fz of [-25, 25]) {
    const floodlightItem = makePointLight({
      name: 'MainStreetFloodLight',
      color: [1.0, 0.96, 0.90],
      brightness: 4.8,
      range: 55,
      shadows: true,
    });
    townChildren.push(makePart({
      name: 'DepotFloodTower',
      cf: cframe(-21, 14, fz),
      size: [1.6, 26, 1.6],
      color: [0.30, 0.32, 0.35],
      material: MAT.Metal,
      children: [floodlightItem],
    }));
  }

  // =========================================================
  // 7. ABANDONED VEHICLES (MATCHING THE REFERENCE IMAGE)
  // =========================================================
  // 1980s wood-paneled station wagon parked along curb on the left
  townChildren.push(buildAbandonedCar(-14, 1.2, 18, -12, 'StationWagon'));
  // Vintage sedan parked crookedly on the right curb
  townChildren.push(buildAbandonedCar(15, 1.2, -15, 25, 'Sedan'));
  // Rusted pickup truck abandoned near Pine Street intersection
  townChildren.push(buildAbandonedCar(-14, 1.2, -75, 8, 'Pickup'));
  // Abandoned car on Elm Street
  townChildren.push(buildAbandonedCar(-115, 1.2, 80, 85, 'Sedan'));
  // Abandoned car on Oak Avenue
  townChildren.push(buildAbandonedCar(115, 1.2, 210, -78, 'StationWagon'));
  // Police cruiser / sedan parked outside diner
  townChildren.push(buildAbandonedCar(-15, 1.2, 55, 180, 'Sedan'));

  // =========================================================
  // 8. PLAYER SPAWN LOCATION (RIGHT ON MAIN STREET / TOWN SQUARE)
  // =========================================================
  const spawnRef = nextRef();
  const spawnXml = `  <Item class="SpawnLocation" referent="${spawnRef}">
    <Properties>
      <string name="Name">ChaserSpawn</string>
      <bool name="Anchored">true</bool>
      <token name="Material">${MAT.DiamondPlate}</token>
      <Vector3 name="size"><X>16</X><Y>1.2</Y><Z>16</Z></Vector3>
      <int name="Duration">0</int>
      <CoordinateFrame name="CFrame">
        <X>0</X><Y>2.2</Y><Z>0</Z>
        <R00>1</R00><R01>0</R01><R02>0</R02>
        <R10>0</R10><R11>1</R11><R12>0</R12>
        <R20>0</R20><R21>0</R21><R22>1</R22>
      </CoordinateFrame>
      <Color3 name="Color"><R>0.2</R><G>0.3</G><B>0.4</B></Color3>
    </Properties>
  </Item>\n`;
  townChildren.push(spawnXml);

  // Wrap all town instances inside the root "SilentHillTown" Model
  const fullTownModel = makeModel('SilentHillTown', townChildren);

  const finalXml = `<?xml version="1.0" encoding="utf-8"?>
<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
  <Meta name="ExplicitAutoJoints">true</Meta>
${fullTownModel}
</roblox>`;

  return finalXml;
}

const outputPath = path.resolve('src/world/SilentHillTown.rbxmx');
console.log('Generating Silent Hill Town model at:', outputPath);
const xml = generateFullTownXml();
fs.writeFileSync(outputPath, xml, 'utf8');
console.log(`Generated SilentHillTown.rbxmx successfully! Size: ${(Buffer.byteLength(xml) / 1024).toFixed(1)} KB`);
