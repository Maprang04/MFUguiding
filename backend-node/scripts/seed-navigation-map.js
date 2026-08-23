'use strict';

const mongoose = require('mongoose');
const config = require('../config/config');
const Floor = require('../server/Project/navigation/models/floor.model');
const Destination = require('../server/Project/navigation/models/destination.model');
const AccessPoint = require('../server/Project/navigation/models/access-point.model');
const Zone = require('../server/Project/navigation/models/zone.model');

const now = new Date();

const floor = {
  floorId: 'floor-1',
  buildingId: 'mfu-building',
  label: 'Floor 1',
  imageAsset: 'floorplan_clean.png',
  imageWidth: 2048,
  imageHeight: 1095,
  cellSizeMeters: 0.25,
  xRange: [0, 23],
  yRange: [0, 12],
  transform: {
    a: 81.75973015049297,
    b: 83.54800207576601,
    c: -91.0665258711722,
    d: 1092.7911826821548
  },
  active: true
};

const destinations = [
  {
    destinationId: 'room_1',
    floorId: 'floor-1',
    label: 'Room 1 entrance',
    nameEn: 'Room 1',
    nameTh: 'ห้อง 1',
    roomNumber: '1',
    category: 'room',
    searchKeywords: ['room 1', 'ห้อง 1'],
    position: { x: 15, y: 5 },
    active: true
  },
  {
    destinationId: 'room_2',
    floorId: 'floor-1',
    label: 'Room 2 entrance',
    nameEn: 'Room 2',
    nameTh: 'ห้อง 2',
    roomNumber: '2',
    category: 'room',
    searchKeywords: ['room 2', 'ห้อง 2'],
    position: { x: 15, y: 9 },
    active: true
  },
  {
    destinationId: 'room_3',
    floorId: 'floor-1',
    label: 'Room 3 entrance',
    nameEn: 'Room 3',
    nameTh: 'ห้อง 3',
    roomNumber: '3',
    category: 'room',
    searchKeywords: ['room 3', 'ห้อง 3'],
    position: { x: 11, y: 5 },
    active: true
  }
];

const zones = [
  {
    zoneId: 'LEFT_WING',
    floorId: 'floor-1',
    label: 'Room 3 / left hallway area',
    transitions: [
      { fromAp: 'AP3', toAp: 'AP2', position: { x: 9.125, y: 3.625 } }
    ],
    active: true
  },
  {
    zoneId: 'CENTRAL_HALLWAY',
    floorId: 'floor-1',
    label: 'Central hallway / Room 2 area',
    transitions: [
      { fromAp: 'AP2', toAp: 'AP3', position: { x: 9.125, y: 3.625 } },
      { fromAp: 'AP2', toAp: 'AP1', position: { x: 14.125, y: 4.125 } }
    ],
    active: true
  },
  {
    zoneId: 'RIGHT_WING',
    floorId: 'floor-1',
    label: 'Room 1 / right hallway area',
    transitions: [
      { fromAp: 'AP1', toAp: 'AP2', position: { x: 14.125, y: 4.125 } }
    ],
    active: true
  }
];

const accessPoints = [
  {
    apId: 'AP1',
    floorId: 'floor-1',
    position: { x: 17, y: 5 },
    zoneId: 'RIGHT_WING',
    anchors: {
      near: { x: 16.125, y: 8.125 },
      medium: { x: 15.125, y: 6.125 },
      edge: { x: 14.125, y: 4.125 }
    },
    active: true
  },
  {
    apId: 'AP2',
    floorId: 'floor-1',
    position: { x: 10.5, y: 9.75 },
    zoneId: 'CENTRAL_HALLWAY',
    anchors: {
      near: { x: 11.125, y: 7.125 },
      medium: { x: 12.125, y: 4.125 },
      edge: { x: 9.125, y: 3.625 }
    },
    active: true
  },
  {
    apId: 'AP3',
    floorId: 'floor-1',
    position: { x: 2, y: 0.5 },
    zoneId: 'LEFT_WING',
    anchors: {
      near: { x: 3.125, y: 2.125 },
      medium: { x: 6.125, y: 2.125 },
      edge: { x: 9.125, y: 3.625 }
    },
    active: true
  }
];

async function upsert(Model, key, item) {
  await Model.updateOne(
    { [key]: item[key] },
    {
      $set: Object.assign({}, item, { updatedAt: now }),
      $setOnInsert: { createdAt: now }
    },
    { upsert: true, runValidators: true }
  );
}

async function main() {
  await mongoose.connect(config.mongoURI, {
    useNewUrlParser: true,
    useUnifiedTopology: true
  });
  await upsert(Floor, 'floorId', floor);
  await Promise.all(destinations.map(function (item) {
    return upsert(Destination, 'destinationId', item);
  }));
  await Promise.all(zones.map(function (item) {
    return upsert(Zone, 'zoneId', item);
  }));
  await Promise.all(accessPoints.map(function (item) {
    return upsert(AccessPoint, 'apId', item);
  }));
  console.log(JSON.stringify({
    seeded: {
      floors: 1,
      destinations: destinations.length,
      access_points: accessPoints.length,
      zones: zones.length
    }
  }));
}

main()
  .then(() => mongoose.connection.close())
  .catch(async function (error) {
    console.error(error.message);
    await mongoose.connection.close();
    process.exitCode = 1;
  });
