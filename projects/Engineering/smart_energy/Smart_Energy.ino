#include <LiquidCrystal.h>

// Initialize LCD: LiquidCrystal(RS, E, D4, D5, D6, D7)
// Based on your Arduino image: RS=12, E=11, D4=5, D5=4, D6=3, D7=2
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

const int voltagePin = A0;

// Calibration parameters
const float adcRef = 5.0;
const int adcResolution = 1023;

// Voltage divider values (Updated to match your 1M/10k ratio)
const float R1 = 1000000.0;  // 1MΩ
const float R2 = 10000.0;    // 10kΩ
const float dividerRatio = (R1 + R2) / R2;

// Load resistance (simulated)
const float loadResistance = 100.0; 

// Energy parameters
float energy_kWh = 0.0;
unsigned long lastTime = 0;

// Tariff
const float tariff = 60.0; // ₦ per kWh

void setup() {
  Serial.begin(9600);
  
  // Initialize LCD
  lcd.begin(16, 2);
  lcd.print("SMART METER");
  lcd.setCursor(0, 1);
  lcd.print("INITIALIZING...");
  
  delay(2000);
  lcd.clear();
  
  lastTime = millis();
}

void loop() {
  // ---- RMS Voltage Measurement ----
  float sumSquares = 0.0;
  const int samples = 200;

  for (int i = 0; i < samples; i++) {
    int adcValue = analogRead(voltagePin);
    float voltage = (adcValue * adcRef) / adcResolution;
    voltage -= 2.5; // Remove DC offset
    sumSquares += voltage * voltage;
    delayMicroseconds(200);
  }

  float rmsVoltage = sqrt(sumSquares / samples);
  float calibrationFactor = 0.90; 
  float realVoltage = rmsVoltage * dividerRatio * calibrationFactor;

  // ---- Calculations ----
  float current = realVoltage / loadResistance;
  float power = realVoltage * current;

  unsigned long currentTime = millis();
  float elapsedHours = (currentTime - lastTime) / 3600000.0;
  energy_kWh += (power * elapsedHours) / 1000.0;
  lastTime = currentTime;

  float cost = energy_kWh * tariff;

  // ---- LCD Output (Screen 1: V & I) ----
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Volt: "); lcd.print(realVoltage, 1); lcd.print("V");
  
  lcd.setCursor(0, 1);
  lcd.print("Curr: "); lcd.print(current, 2); lcd.print("A");
  
  delay(3000); // Display V and I for 3 seconds

  // ---- LCD Output (Screen 2: P & Cost) ----
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Powr: "); lcd.print(power, 1); lcd.print("W");
  
  lcd.setCursor(0, 1);
  lcd.print("Cost: "); lcd.print("N"); lcd.print(cost, 2);
  
  delay(3000); // Display P and Cost for 3 seconds

  // ---- Serial Output (Kept for COMPIM) ----
  Serial.print(realVoltage, 2);
  Serial.print(",");
  Serial.print(current, 2);
  Serial.print(",");
  Serial.print(power, 2);
  Serial.print(",");
  Serial.print(energy_kWh, 5);
  Serial.print(",");
  Serial.println(cost, 2);
}