<script setup lang="ts">
import { useCounterStore } from '../stores/counter'

const counter = useCounterStore()
</script>

<template>
  <section>
    <h1>Hello from {{SERVICE}}</h1>
    <button @click="counter.increment">count is {{ counter.count }}</button>
  </section>
</template>
