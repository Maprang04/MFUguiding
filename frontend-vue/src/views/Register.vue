<template>
  <div class="register-page">
    <div class="register-card">
      <h1>ลงทะเบียน</h1>
      <p>กรุณากรอกข้อมูลเพื่อสร้างบัญชีผู้ใช้งาน</p>

      <form @submit.prevent="submitRegister">
        <div class="form-group">
          <label for="name">ชื่อ</label>
          <input id="name" v-model="form.name" type="text" class="form-control" placeholder="ชื่อของคุณ" required />
        </div>
        <div class="form-group">
          <label for="email">อีเมล</label>
          <input id="email" v-model="form.email" type="email" class="form-control" placeholder="your@example.com" required />
        </div>
        <div class="form-group">
          <label for="password">รหัสผ่าน</label>
          <input id="password" v-model="form.password" type="password" class="form-control" placeholder="รหัสผ่าน" required />
        </div>
        <div class="form-group">
          <label for="confirmPassword">ยืนยันรหัสผ่าน</label>
          <input id="confirmPassword" v-model="form.confirmPassword" type="password" class="form-control" placeholder="ยืนยันรหัสผ่าน" required />
        </div>
        <button type="submit" class="btn btn-primary btn-block">สมัครใช้งาน</button>
      </form>

      <div v-if="message" class="register-message">
        {{ message }}
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'Register',
  data() {
    return {
      form: {
        name: '',
        email: '',
        password: '',
        confirmPassword: ''
      },
      message: ''
    }
  },
  methods: {
    submitRegister() {
      if (this.form.password !== this.form.confirmPassword) {
        this.message = 'รหัสผ่านทั้งสองช่องไม่ตรงกัน'
        return
      }
      this.message = 'บันทึกข้อมูลเรียบร้อยแล้ว (ตัวอย่างเฉพาะฝั่งหน้า)' 
    }
  }
}
</script>

<style scoped>
.register-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 75vh;
  padding: 2rem;
}

.register-card {
  width: 100%;
  max-width: 520px;
  padding: 2.5rem;
  border-radius: 1rem;
  background-color: #ffffff;
  box-shadow: 0 18px 40px rgba(15, 23, 42, 0.12);
}

.register-card h1 {
  margin-bottom: 0.75rem;
  font-size: 2rem;
  font-weight: 700;
}

.register-card p {
  margin-bottom: 1.5rem;
  color: #64748b;
}

.form-group {
  margin-bottom: 1rem;
}

.register-message {
  margin-top: 1rem;
  color: #0f5132;
  background-color: #d1e7dd;
  padding: 1rem;
  border-radius: 0.75rem;
}
</style>
