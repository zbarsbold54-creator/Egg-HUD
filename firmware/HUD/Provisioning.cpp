#include "Provisioning.h"
#include "Config.h"
#include "WiFiManager.h"
#include "DisplayDriver.h"
#include <WiFi.h>
#include <WebServer.h>

Provisioning Provision;
static WebServer server(80);
static bool credentialsReceived = false;

static const char* FORM_HTML =
  "<!DOCTYPE html><html><body>"
  "<h2>HUD WiFi Setup</h2>"
  "<form method='POST' action='/connect'>"
  "SSID: <input name='ssid'><br>"
  "Password: <input name='password' type='password'><br>"
  "<input type='submit' value='Connect'>"
  "</form></body></html>";

String Provisioning::apSSID() const {
  uint64_t chipId = ESP.getEfuseMac();
  char suffix[5];
  snprintf(suffix, sizeof(suffix), "%04X", (uint16_t)(chipId & 0xFFFF));
  return String(PROVISION_AP_PREFIX) + suffix;
}

void Provisioning::begin() {
  credentialsReceived = false;

  // AP_STA (not AP-only) so STA scanning/joining still works while the
  // setup AP is active — HUD.ino retries known networks from PROVISIONING.
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(apSSID().c_str());   // open network, setup-only
  Serial.print(F("[PROV] AP started: "));
  Serial.println(apSSID());

  server.on("/", HTTP_GET, []() {
    server.send(200, "text/html", FORM_HTML);
  });

  // Brain App posts { ssid, password } as normal form fields.
  server.on("/connect", HTTP_POST, []() {
    if (!server.hasArg("ssid")) {
      server.send(400, "text/plain", "missing ssid");
      return;
    }
    String ssid = server.arg("ssid");
    String pass = server.hasArg("password") ? server.arg("password") : "";

    Wifi.addNetwork(ssid, pass);
    credentialsReceived = true;
    Serial.print(F("[PROV] credentials saved for: "));
    Serial.println(ssid);
    Display.clear();
    Display.drawText(0, 32, "saving... rebooting");
    Display.present();

    server.send(200, "text/plain", "saved, rebooting");
  });

  server.begin();
}

void Provisioning::loop() {
  server.handleClient();

  if (credentialsReceived) {
    delay(300);   // let the HTTP response flush before we tear things down
    end();
    ESP.restart();
  }
}

void Provisioning::end() {
  server.stop();
  WiFi.softAPdisconnect(true);
  WiFi.mode(WIFI_STA);  // return to STA-only for RUNNING
}

bool Provisioning::hasClient() const {
  return WiFi.softAPgetStationNum() > 0;
}
