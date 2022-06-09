module.exports = {
  content: ["./**/*.{html,js}", "./dist/page/**/*.html"],
  darkMode: "class",
  theme: {
    extend: {
      keyframes: {
        "text-shimmer": {
          from: { backgroundPosition: "0 0" },
          to: { backgroundPosition: "-200% 0" },
        },
        swing: {
          "15%": { transform: "rotate(20deg)" },
          "30%": { transform: "rotate(-20deg)" },
          "50%": { transform: "rotate(10deg)" },
          "80%": { transform: "rotate(-10deg)" },
          "100%": { transform: "rotate(0deg)" },
        },
      },

      animation: {
        "text-shimmer": "text-shimmer 2.5s ease-out infinite alternate",
        "swing": "swing 1s ease 1",
      },
    },
  },
  plugins: [],
}
