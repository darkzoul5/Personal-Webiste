// Function to apply the saved theme or system preference
function applyTheme(theme) {
    document.body.classList.remove('light-mode', 'dark-mode'); // Remove existing theme classes
    document.body.classList.add(theme + '-mode'); // Add the selected theme

    const sunIcon = document.getElementById('sun-icon');
    const moonIcon = document.getElementById('moon-icon');

    if (theme === 'dark') {
        sunIcon.style.display = 'none';  // Hide the sun icon
        moonIcon.style.display = 'inline';  // Show the moon icon
    } else {
        sunIcon.style.display = 'inline';  // Show the sun icon
        moonIcon.style.display = 'none';  // Hide the moon icon
    }

    // Store the current theme in localStorage
    localStorage.setItem('theme', theme);
}

// Check if a theme is saved in localStorage, otherwise, detect the system preference
let currentTheme = localStorage.getItem('theme');

// Apply the saved theme immediately on page load, if available
if (currentTheme) {
    applyTheme(currentTheme);
} else {
    // If no theme is set, check the system preference
    const prefersDarkScheme = window.matchMedia('(prefers-color-scheme: dark)').matches;
    currentTheme = prefersDarkScheme ? 'dark' : 'light';
    applyTheme(currentTheme);
}

// Event listener for the toggle button
const toggleButton = document.getElementById('theme-toggle');

toggleButton.addEventListener('click', () => {
    const currentTheme = document.body.classList.contains('dark-mode') ? 'dark' : 'light';
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';

    applyTheme(newTheme);
});
