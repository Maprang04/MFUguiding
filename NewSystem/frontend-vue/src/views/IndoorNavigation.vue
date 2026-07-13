<template>
  <div class="app-shell">
    <div class="demo-card">
      <div class="demo-head">
        <div>
          <p class="eyebrow">Indoor Navigation Demo</p>
          <h1>MFU SmartGuide MVP</h1>
        </div>
        <button class="mini-button" @click="checkHealth">Health</button>
      </div>

      <div class="config-bar">
        <label class="host-field">
          <span>API Host</span>
          <input v-model="apiHost" type="text" placeholder="192.168.1.25" />
        </label>
        <div class="config-actions">
          <button class="mini-button" @click="saveApiHost">Save Host</button>
          <button class="mini-button alt-button" @click="useCurrentHost">Use Current</button>
        </div>
      </div>
      <p class="helper-text">Host จะถูกจำไว้ในเบราว์เซอร์ของคุณ ทำให้เปิดจากมือถือครั้งต่อไปไม่ต้องพิมพ์ซ้ำ</p>

      <section class="map-panel">
        <div class="map-head">
          <h2>Floor Plan</h2>
          <span class="location-badge">{{ locationBadge }}</span>
        </div>
        <div class="map-stage">
          <img class="map-floor-image" src="/img/ac.png" alt="Indoor navigation floor plan" />
          <div class="map-grid" aria-hidden="true"></div>
          <div v-if="currentPosition" class="map-marker" :style="markerStyle">
            <span class="map-marker-dot"></span>
            <span class="map-marker-label">x={{ currentPosition.x }}, y={{ currentPosition.y }}</span>
          </div>
          <div v-else class="map-marker idle-marker" :style="defaultMarkerStyle">
            <span class="map-marker-dot"></span>
            <span class="map-marker-label">Waiting for result</span>
          </div>
        </div>
      </section>

      <div class="panel-grid">
        <section class="panel">
          <h2>Locate by RSSI</h2>
          <div class="field-grid">
            <label>
              <span>AP1</span>
              <input v-model.number="ap1" type="number" step="1" />
            </label>
            <label>
              <span>AP2</span>
              <input v-model.number="ap2" type="number" step="1" />
            </label>
            <label>
              <span>AP3</span>
              <input v-model.number="ap3" type="number" step="1" />
            </label>
          </div>
          <button class="primary-button" @click="runLocate" :disabled="loading">
            {{ loading ? 'Working...' : 'Locate via Backend' }}
          </button>
        </section>

        <section class="panel">
          <h2>Explain Position</h2>
          <div class="field-grid two-col">
            <label>
              <span>X</span>
              <input v-model.number="x" type="number" step="0.1" />
            </label>
            <label>
              <span>Y</span>
              <input v-model.number="y" type="number" step="0.1" />
            </label>
          </div>
          <button class="secondary-button" @click="runExplain" :disabled="loading">
            Explain Position
          </button>
        </section>

        <section class="panel">
          <h2>Save Fingerprint</h2>
          <div class="field-grid three-col">
            <label>
              <span>AP1</span>
              <input v-model.number="saveAp1" type="number" step="1" />
            </label>
            <label>
              <span>AP2</span>
              <input v-model.number="saveAp2" type="number" step="1" />
            </label>
            <label>
              <span>AP3</span>
              <input v-model.number="saveAp3" type="number" step="1" />
            </label>
            <label>
              <span>X</span>
              <input v-model.number="saveX" type="number" step="0.1" />
            </label>
            <label>
              <span>Y</span>
              <input v-model.number="saveY" type="number" step="0.1" />
            </label>
          </div>
          <button class="primary-button" @click="savePoint" :disabled="loading">
            Save Point
          </button>
        </section>
      </div>

      <div class="response-box">
        <div class="response-head">
          <strong>Backend Response</strong>
        </div>
        <pre>{{ responseText || 'Response will be shown here.' }}</pre>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios'

const API_HOST_STORAGE_KEY = 'indoor_navigation_api_host'
const API_PORT = 3000

export default {
  name: 'IndoorNavigation',
  data() {
    return {
      apiHost: this.getDefaultApiHost(),
      ap1: -67,
      ap2: -68,
      ap3: -61,
      x: 9,
      y: 2,
      saveAp1: -67,
      saveAp2: -68,
      saveAp3: -61,
      saveX: 9,
      saveY: 2,
      loading: false,
      responseText: '',
      currentPosition: null
    }
  },
  computed: {
    apiBaseUrl() {
      const host = this.normalizeApiHost(this.apiHost)
      return `http://${host}:${API_PORT}`
    },
    markerPosition() {
      const gridWidth = 22
      const gridHeight = 12

      if (!this.currentPosition || typeof this.currentPosition.x !== 'number' || typeof this.currentPosition.y !== 'number') {
        return { left: 2.27, top: 95.83 }
      }

      const clampedX = Math.max(0, Math.min(gridWidth, this.currentPosition.x))
      const clampedY = Math.max(0, Math.min(gridHeight, this.currentPosition.y))
      const left = ((clampedX + 0.5) / gridWidth) * 100
      const top = 100 - ((clampedY + 0.5) / gridHeight) * 100

      return {
        left: Number(Math.max(0, Math.min(100, left)).toFixed(2)),
        top: Number(Math.max(0, Math.min(100, top)).toFixed(2))
      }
    },
    markerStyle() {
      const { left, top } = this.markerPosition
      return {
        left: `${left}%`,
        top: `${top}%`
      }
    },
    defaultMarkerStyle() {
      return {
        left: '2.27%',
        top: '95.83%'
      }
    },
    locationBadge() {
      if (!this.currentPosition) {
        return 'Waiting for locate result'
      }

      const area = this.currentPosition.location_th || this.currentPosition.location_en || 'Unknown area'
      return `${area} (${this.currentPosition.x}, ${this.currentPosition.y})`
    }
  },
  methods: {
    getDefaultApiHost() {
      try {
        const storedHost = window.localStorage.getItem(API_HOST_STORAGE_KEY)
        if (storedHost) {
          return storedHost
        }
      } catch (error) {
        console.warn('Unable to read saved host from localStorage', error)
      }

      return window.location.hostname || '127.0.0.1'
    },
    normalizeApiHost(value) {
      const host = (value || '').trim().replace(/^https?:\/\//, '').replace(/:\d+$/, '')
      return host || window.location.hostname || '127.0.0.1'
    },
    saveApiHost() {
      const host = this.normalizeApiHost(this.apiHost)
      this.apiHost = host

      try {
        window.localStorage.setItem(API_HOST_STORAGE_KEY, host)
      } catch (error) {
        console.warn('Unable to save host to localStorage', error)
      }

      this.responseText = `API host saved: ${this.apiBaseUrl}`
    },
    useCurrentHost() {
      this.apiHost = this.getDefaultApiHost()
      this.responseText = `Using current browser host: ${this.apiBaseUrl}`
    },
    async callApi(endpoint, payload) {
      this.loading = true
      this.responseText = ''

      try {
        const response = await axios.post(`${this.apiBaseUrl}${endpoint}`, payload)
        this.responseText = JSON.stringify(response.data, null, 2)

        if (response.data && typeof response.data.x === 'number' && typeof response.data.y === 'number') {
          this.currentPosition = response.data
        }
      } catch (error) {
        const message = error.response && error.response.data && error.response.data.error
          ? error.response.data.error
          : error.message || 'Unknown error'
        this.responseText = `Request failed: ${message}`
      } finally {
        this.loading = false
      }
    },
    async checkHealth() {
      this.loading = true
      this.responseText = ''

      try {
        const response = await axios.get(`${this.apiBaseUrl}/health`)
        this.responseText = JSON.stringify(response.data, null, 2)
      } catch (error) {
        const message = error.response && error.response.data && error.response.data.error
          ? error.response.data.error
          : error.message || 'Unknown error'
        this.responseText = `Health check failed: ${message}`
      } finally {
        this.loading = false
      }
    },
    async runLocate() {
      await this.callApi('/locate', { ap1: this.ap1, ap2: this.ap2, ap3: this.ap3 })
    },
    async runExplain() {
      await this.callApi('/explain', { x: this.x, y: this.y })
    },
    async savePoint() {
      await this.callApi('/save-point', {
        ap1: this.saveAp1,
        ap2: this.saveAp2,
        ap3: this.saveAp3,
        x: this.saveX,
        y: this.saveY
      })
    }
  }
}
</script>

<style lang="scss" scoped>
.app-shell {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: linear-gradient(135deg, #ff5252 0%, #d62828 100%);
}

.demo-card {
  width: min(980px, 100%);
  background: rgba(255, 255, 255, 0.94);
  border-radius: 20px;
  padding: 24px;
  box-shadow: 0 18px 40px rgba(0, 0, 0, 0.18);
}

.demo-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
}

.map-panel {
  margin: 0 0 18px;
  background: #fff;
  border-radius: 14px;
  padding: 14px;
  border: 1px solid #f0caca;
}

.map-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
}

.location-badge {
  background: #fff1f1;
  color: #b53c3c;
  border-radius: 999px;
  padding: 6px 10px;
  font-size: 12px;
  font-weight: 700;
}

.map-stage {
  position: relative;
  width: 100%;
  overflow: auto;
  border-radius: 16px;
  background: linear-gradient(180deg, #fffdfd 0%, #f9ebeb 100%);
  border: 1px solid #efcfcf;
  box-shadow: inset 0 0 0 1px rgba(255,255,255,0.55);
}

.map-floor-image {
  width: 960px;
  height: auto;
  max-width: none;
  display: block;
  background: #fff;
}

.map-grid {
  position: absolute;
  inset: 0;
  z-index: 1;
  pointer-events: none;
  background-image:
    linear-gradient(to right, rgba(149, 39, 39, 0.22) 1px, transparent 1px),
    linear-gradient(to bottom, rgba(149, 39, 39, 0.22) 1px, transparent 1px);
  background-size: calc(100% / 22) 100%, 100% calc(100% / 12);
  opacity: 0.9;
}

.map-overlay {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}

.map-marker {
  position: absolute;
  transform: translate(-50%, -50%);
  display: flex;
  align-items: center;
  gap: 8px;
  z-index: 3;
}

.map-marker-dot {
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: #d62828;
  border: 3px solid #fff;
  box-shadow: 0 0 0 5px rgba(214, 40, 40, 0.18);
}

.map-marker-label {
  background: rgba(255, 255, 255, 0.96);
  color: #7c2c2c;
  border: 1px solid #efcaca;
  border-radius: 999px;
  padding: 4px 8px;
  font-size: 11px;
  font-weight: 700;
  white-space: nowrap;
}

.idle-marker {
  opacity: 0.6;
}

.config-bar {
  display: flex;
  gap: 12px;
  align-items: flex-end;
  margin-bottom: 10px;
}

.host-field {
  flex: 1;
}

.config-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.helper-text {
  margin: 0 0 16px;
  font-size: 12px;
  color: #6d4242;
}


h1 {
  margin: 0;
  color: #3c1f1f;
}

h2 {
  margin: 0 0 12px 0;
  font-size: 18px;
}

.panel-grid {
  display: grid;
  gap: 14px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.panel {
  background: #fff7f7;
  border-radius: 14px;
  padding: 16px;
}

.field-grid {
  display: grid;
  gap: 12px;
}

.two-col {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.three-col {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

label {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 13px;
  font-weight: 700;
  color: #4d2d2d;
}

input {
  width: 100%;
  border: 1px solid #d9b1b1;
  border-radius: 10px;
  padding: 10px 12px;
  font-size: 14px;
}

.primary-button,
.secondary-button,
.mini-button {
  border: none;
  border-radius: 999px;
  cursor: pointer;
  font-weight: 700;
}

.primary-button {
  margin-top: 16px;
  background: #d62828;
  color: #fff;
  padding: 11px 18px;
}

.secondary-button {
  margin-top: 16px;
  background: #fff;
  color: #d62828;
  padding: 11px 18px;
  border: 1px solid #d62828;
}

.mini-button {
  background: #d62828;
  color: #fff;
  padding: 8px 14px;
}

.alt-button {
  background: #fff;
  color: #d62828;
  border: 1px solid #d62828;
}

.response-box {
  margin-top: 18px;
  background: #fff;
  border-radius: 14px;
  padding: 14px;
  border: 1px solid #f1d7d7;
}

.response-head {
  margin-bottom: 10px;
  color: #882c2c;
}

pre {
  margin: 0;
  white-space: pre-wrap;
  font-size: 12px;
  color: #5b3737;
}

@media (max-width: 900px) {
  .panel-grid {
    grid-template-columns: 1fr;
  }

  .map-head {
    flex-direction: column;
    align-items: flex-start;
  }

  .config-bar {
    flex-direction: column;
    align-items: stretch;
  }

  .config-actions {
    width: 100%;
  }

  .config-actions .mini-button {
    flex: 1;
  }
}

@media (max-width: 620px) {
  .app-shell {
    padding: 12px;
  }

  .demo-card {
    padding: 16px;
    width: 100%;
  }

  .map-stage {
    min-height: 330px;
    height: 58vh;
  }

  .two-col,
  .three-col {
    grid-template-columns: 1fr;
  }

  .demo-head {
    flex-direction: column;
    align-items: stretch;
  }

  .config-actions {
    flex-direction: column;
  }

  .primary-button,
  .secondary-button,
  .mini-button {
    width: 100%;
  }
}
</style>
