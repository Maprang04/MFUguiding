<template>
  <div class="splash-container">
    <div class="splash-content">
      <div class="logo-container">
        <svg class="mfu-logo" viewBox="0 0 200 240" xmlns="http://www.w3.org/2000/svg">
          <circle cx="100" cy="80" r="35" fill="#FFC107" stroke="#FFF" stroke-width="3"/>
          <path d="M 100 25 L 110 45 L 130 45 L 115 55 L 120 75 L 100 65 L 80 75 L 85 55 L 70 45 L 90 45 Z"
                fill="#FF5252" />
          <circle cx="75" cy="120" r="8" fill="#FFF" stroke="#FFD54F" stroke-width="2"/>
          <circle cx="125" cy="120" r="8" fill="#FFF" stroke="#FFD54F" stroke-width="2"/>
          <path d="M 100 90 Q 85 110 100 130 Q 115 110 100 90" fill="#FFD54F" stroke="#FFF" stroke-width="2"/>
          <path d="M 60 150 Q 50 140 45 160 Q 50 165 60 160" fill="#FFF"/>
          <path d="M 140 150 Q 150 140 155 160 Q 150 165 140 160" fill="#FFF"/>
        </svg>
      </div>

      <h1 class="splash-title">MFU SmartGuide</h1>

      <p class="splash-subtitle">
        MFU WI-FI-BASED ASSISTIVE NAVIGATION<br>
        SYSTEM FOR PEOPLE WITH DISABILITIES
      </p>

      <div class="demo-card">
        <div class="demo-header">
          <span>Quick Model Demo</span>
          <button class="mini-button" @click="checkHealth">Health</button>
        </div>

        <div class="demo-grid">
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

        <div class="demo-actions">
          <button class="start-button" @click="runLocate" :disabled="loading">
            {{ loading ? 'Working...' : 'Locate via Backend' }}
          </button>
        </div>

        <div class="demo-grid explain-grid">
          <label>
            <span>X</span>
            <input v-model.number="x" type="number" step="0.1" />
          </label>
          <label>
            <span>Y</span>
            <input v-model.number="y" type="number" step="0.1" />
          </label>
        </div>

        <div class="demo-actions">
          <button class="secondary-button" @click="runExplain" :disabled="loading">
            Explain Position
          </button>
        </div>

        <pre class="result-box">{{ responseText || 'Backend response will appear here.' }}</pre>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios'

const INDOOR_API_BASE_URL = 'http://127.0.0.1:3000'

export default {
  name: 'Splash',
  data() {
    return {
      ap1: -67,
      ap2: -68,
      ap3: -61,
      x: 9,
      y: 2,
      loading: false,
      responseText: ''
    }
  },
  methods: {
    async callBackend(endpoint, payload) {
      this.loading = true
      this.responseText = ''

      try {
        const response = await axios.post(`${INDOOR_API_BASE_URL}${endpoint}`, payload)
        this.responseText = JSON.stringify(response.data, null, 2)
      } catch (error) {
        const message = error.response && error.response.data && error.response.data.error
          ? error.response.data.error
          : error.message || 'Unknown error'
        this.responseText = `Request failed: ${message}`
      } finally {
        this.loading = false
      }
    },
    async handleStart() {
      await this.checkHealth()
    },
    async checkHealth() {
      this.loading = true
      this.responseText = ''

      try {
        const response = await axios.get(`${INDOOR_API_BASE_URL}/health`)
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
      await this.callBackend('/locate', { ap1: this.ap1, ap2: this.ap2, ap3: this.ap3 })
    },
    async runExplain() {
      await this.callBackend('/explain', { x: this.x, y: this.y })
    }
  }
}
</script>

<style lang="scss" scoped>
.splash-container {
  width: 100%;
  min-height: 100vh;
  background: linear-gradient(135deg, #FF5252 0%, #E53935 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
}

.splash-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  animation: fadeInUp 0.8s ease-out;
}

.logo-container {
  margin-bottom: 30px;
  animation: bounce 1s ease-in-out infinite;
}

.mfu-logo {
  width: 120px;
  height: 140px;
  filter: drop-shadow(0 4px 8px rgba(0, 0, 0, 0.2));
}

.splash-title {
  font-size: 48px;
  font-weight: 700;
  color: #fff;
  margin: 0 0 15px 0;
  letter-spacing: 2px;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
}

.splash-subtitle {
  font-size: 14px;
  color: rgba(255, 255, 255, 0.95);
  margin: 0 0 40px 0;
  line-height: 1.6;
  letter-spacing: 0.5px;
  max-width: 320px;
  font-weight: 500;
}

.start-button {
  width: 240px;
  padding: 16px 24px;
  font-size: 18px;
  font-weight: 700;
  color: #E53935;
  background-color: #fff;
  border: none;
  border-radius: 30px;
  cursor: pointer;
  transition: all 0.3s ease;
  box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
  letter-spacing: 1px;

  &:hover {
    transform: translateY(-3px);
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.3);
    background-color: #f5f5f5;
  }

  &:active {
    transform: translateY(-1px);
    box-shadow: 0 3px 10px rgba(0, 0, 0, 0.2);
  }
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes bounce {
  0%, 100% {
    transform: translateY(0);
  }
  50% {
    transform: translateY(-10px);
  }
}

/* Responsive design */
@media (max-width: 768px) {
  .splash-container {
    padding: 20px;
  }

  .splash-title {
    font-size: 36px;
    margin-bottom: 12px;
  }

  .splash-subtitle {
    font-size: 12px;
    margin-bottom: 30px;
    max-width: 280px;
  }

  .start-button {
    width: 200px;
    padding: 14px 20px;
    font-size: 16px;
  }

  .mfu-logo {
    width: 100px;
    height: 120px;
  }
}

.demo-card {
  width: min(560px, 100%);
  margin-top: 24px;
  padding: 20px;
  background: rgba(255, 255, 255, 0.92);
  border-radius: 18px;
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.15);
  color: #4b2f2f;
}

.demo-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 16px;
  font-weight: 700;
}

.demo-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.explain-grid {
  grid-template-columns: repeat(2, minmax(0, 1fr));
  margin-top: 14px;
}

.demo-grid label {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 13px;
  font-weight: 700;
}

.demo-grid input {
  width: 100%;
  border: 1px solid #d2b6b6;
  border-radius: 10px;
  padding: 10px 12px;
  font-size: 14px;
}

.demo-actions {
  margin-top: 14px;
}

.secondary-button,
.mini-button {
  border: none;
  border-radius: 999px;
  cursor: pointer;
  font-weight: 700;
}

.secondary-button {
  background: #fff;
  color: #d62828;
  padding: 11px 18px;
}

.mini-button {
  background: #d62828;
  color: #fff;
  padding: 8px 14px;
}

.result-box {
  margin-top: 16px;
  padding: 12px;
  background: #fff7f7;
  border-radius: 12px;
  color: #693939;
  font-size: 12px;
  overflow: auto;
  white-space: pre-wrap;
}

@media (max-width: 768px) {
  .demo-grid {
    grid-template-columns: 1fr;
  }

  .explain-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 480px) {
  .splash-title {
    font-size: 28px;
  }

  .splash-subtitle {
    font-size: 11px;
    max-width: 240px;
  }

  .start-button {
    width: 160px;
    padding: 12px 16px;
    font-size: 14px;
  }

  .mfu-logo {
    width: 80px;
    height: 100px;
  }
}
</style>
