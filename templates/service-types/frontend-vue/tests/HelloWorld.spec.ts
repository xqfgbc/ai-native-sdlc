import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia } from 'pinia'
import HelloWorld from '../src/components/HelloWorld.vue'

describe('HelloWorld', () => {
  it('renders and increments the counter', async () => {
    const wrapper = mount(HelloWorld, { global: { plugins: [createPinia()] } })
    expect(wrapper.text()).toContain('count is 0')
    await wrapper.find('button').trigger('click')
    expect(wrapper.text()).toContain('count is 1')
  })
})
