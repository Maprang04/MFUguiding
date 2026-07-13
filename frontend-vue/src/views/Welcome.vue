<template>
  <div class="welcome-page">
    <div class="welcome-card">
      <h1>สวัสดีครับ</h1>
      <p>ยินดีต้อนรับเข้าสู่ระบบ NewSystem</p>
      <router-link class="btn btn-primary" to="/dashboard">
        เข้าสู่เมนหลัก
      </router-link>
    </div>
  </div>
</template>

<script>
export default {
  name: 'Welcome'
}
</script>

<style scoped>
.welcome-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 75vh;
  padding: 2rem;
}

.welcome-card {
  max-width: 540px;
  width: 100%;
  text-align: center;
  padding: 3rem;
  border-radius: 1rem;
  box-shadow: 0 18px 40px rgba(15, 23, 42, 0.12);
  background-color: #ffffff;
}

.welcome-card h1 {
  margin-bottom: 1rem;
  color: #16293a;
  font-size: 2.5rem;
  font-weight: 700;
}

.welcome-card p {
  margin-bottom: 2rem;
  color: #475569;
  font-size: 1rem;
  line-height: 1.75;
}

.welcome-card .btn {
  min-width: 240px;
}
</style>
