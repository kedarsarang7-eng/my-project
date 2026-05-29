// ============================================================================
// ULID Generator - Time-sortable unique identifiers
// ============================================================================

const ENCODING = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const ENCODING_LEN = 32;
const TIME_LEN = 10;
const RANDOM_LEN = 16;

function encodeTime(now: number, len: number): string {
  let mod: number;
  let str = '';
  for (let i = len - 1; i >= 0; i--) {
    mod = now % ENCODING_LEN;
    str = ENCODING.charAt(mod) + str;
    now = Math.floor(now / ENCODING_LEN);
  }
  return str;
}

function encodeRandom(len: number): string {
  let str = '';
  for (let i = 0; i < len; i++) {
    str += ENCODING.charAt(Math.floor(Math.random() * ENCODING_LEN));
  }
  return str;
}

export function generateULID(): string {
  const now = Date.now();
  return encodeTime(now, TIME_LEN) + encodeRandom(RANDOM_LEN);
}

export function getCurrentTimestamp(): string {
  return new Date().toISOString();
}

export function getCurrentDate(): string {
  return new Date().toISOString().split('T')[0];
}

export function getDateFromTimestamp(timestamp: string): string {
  return timestamp.split('T')[0];
}

export function addMinutesToTime(timeStr: string, minutes: number): string {
  const [hours, mins] = timeStr.split(':').map(Number);
  const totalMinutes = hours * 60 + mins + minutes;
  const newHours = Math.floor(totalMinutes / 60) % 24;
  const newMins = totalMinutes % 60;
  return `${newHours.toString().padStart(2, '0')}:${newMins.toString().padStart(2, '0')}`;
}

export function calculateTimeDifferenceMinutes(startTime: string, endTime: string): number {
  const [startHours, startMins] = startTime.split(':').map(Number);
  const [endHours, endMins] = endTime.split(':').map(Number);
  
  const startTotal = startHours * 60 + startMins;
  const endTotal = endHours * 60 + endMins;
  
  return endTotal - startTotal;
}

export function calculateHoursBetween(startIso: string, endIso: string): number {
  const start = new Date(startIso).getTime();
  const end = new Date(endIso).getTime();
  const diffMs = end - start;
  return Math.round((diffMs / (1000 * 60 * 60)) * 100) / 100; // Round to 2 decimals
}
