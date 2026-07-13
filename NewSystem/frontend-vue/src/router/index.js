import Vue from 'vue'
import Router from 'vue-router'

const IndoorNavigation = () => import('@/views/IndoorNavigation')

Vue.use(Router)

const router = new Router({
  hash: false,
  mode: 'history',
  linkActiveClass: 'open active',
  scrollBehavior: () => ({ y: 0 }),
  routes: [
    {
      path: '/',
      name: 'IndoorNavigation',
      component: IndoorNavigation
    },
    {
      path: '/indoor',
      name: 'IndoorNavigationAlias',
      component: IndoorNavigation
    },
    {
      path: '*',
      redirect: '/'
    }
  ]
})

export default router
