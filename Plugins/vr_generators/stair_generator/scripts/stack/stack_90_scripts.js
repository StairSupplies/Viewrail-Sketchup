let isUpdating = false;

const numTreadsLowerInput = document.getElementById('num_treads_lower');
const numTreadsUpperInput = document.getElementById('num_treads_upper');
const headerToWallInput = document.getElementById('header_to_wall');
const treadWidthLowerInput = document.getElementById('tread_width_lower');
const treadWidthUpperInput = document.getElementById('tread_width_upper');
const landingWidthInput = document.getElementById('landing_width');
const landingDepthInput = document.getElementById('landing_depth');
const treadRunInput = document.getElementById('tread_run');
const totalRiseInput = document.getElementById('total_rise');
const stairRiseInput = document.getElementById('stair_rise');
const turnDirectionSelect = document.getElementById('turn_direction');
const glassRailingSelect = document.getElementById('glass_railing');

const maxTreadsUpperHS = 12;
const maxTreadsLowerHS = 14;

// could make this take variable inputs to consolidate with the lower?
function calculateUpperTreads() {
  const headerToWall = parseFloat(headerToWallInput.value) || 0;
  const treadRun = parseFloat(treadRunInput.value) || 11;

  if (headerToWall > 0 && treadRun > 0) {
    const minLandingWidth = parseFloat(treadWidthLowerInput.value) || 27;
    const availableRun = headerToWall - minLandingWidth;
    const upperTreads = Math.floor(availableRun / treadRun);

    const validUpperTreads = Math.max(1, Math.min(maxTreadsUpperHS, upperTreads));
    numTreadsUpperInput.value = validUpperTreads;
    calculateStairRise();

    const usedRun = (validUpperTreads * treadRun);
    landingWidthInput.value = headerToWall - usedRun;
  }
}

function calculateLowerTreads() {
  const totalRise = parseFloat(totalRiseInput.value) || 0;
  const numTreadsUpper = parseInt(numTreadsUpperInput.value) || 0;
  let numTreadsLower = parseInt(numTreadsLowerInput.value) || 0;

  if (totalRise > 0) {
    const totalTreads = numTreadsLower + numTreadsUpper;
    const calculatedRise = totalRise / (totalTreads + 2);
    if (calculatedRise > 9) {
      while (numTreadsLower < maxTreadsLowerHS) {
        numTreadsLower++;
        const newTotalTreads = numTreadsLower + numTreadsUpper;
        const newRise = totalRise / (newTotalTreads + 2);
        if (newRise <= 9) break;
      }
    } else if (calculatedRise < 6) {
      while (numTreadsLower > 1) {
        numTreadsLower--;
        const newTotalTreads = numTreadsLower + numTreadsUpper;
        const newRise = totalRise / (newTotalTreads + 2);
        if (newRise >= 6) break;
      }
    }

    if (numTreadsLower !== parseInt(numTreadsLowerInput.value)) {
      numTreadsLowerInput.value = numTreadsLower;
      calculateStairRise();
    }
  }
}

function checkLandingSize() {
  const lowerWidth = parseFloat(treadWidthLowerInput.value) || 36;
  const upperWidth = parseFloat(treadWidthUpperInput.value) || 36;
  const landingWidth = parseFloat(landingWidthInput.value) || 36;
  const landingDepth = parseFloat(landingDepthInput.value) || 36;
  if (landingWidth < lowerWidth) {
    landingWidthInput.value = lowerWidth;
    calculateUpperTreads();
    calculateLowerTreads();
  }
  if (landingDepth < upperWidth) {
    landingDepthInput.value = upperWidth;
  }
}

function calculateStairRise() {
  if (isUpdating) return;
  isUpdating = true;

  const numTreadsLower = parseInt(numTreadsLowerInput.value) || 0;
  const numTreadsUpper = parseInt(numTreadsUpperInput.value) || 0;
  const totalTreads = numTreadsLower + numTreadsUpper;
  const totalRise = parseFloat(totalRiseInput.value) || 0;

  if (totalTreads > 0 && totalRise > 0) {
    const stairRise = totalRise / (totalTreads + 2);
    stairRiseInput.value = stairRise.toFixed(2);
  }

  isUpdating = false;
  validateInputs();
}

function updateHeaderToWall() {
  if (isUpdating) return;
  isUpdating = true;

  const numTreadsUpper = parseInt(numTreadsUpperInput.value) || 0;
  const landingWidth = parseFloat(landingWidthInput.value) || 36;
  const treadRun = parseFloat(treadRunInput.value) || 11;

  if (numTreadsUpper > 0 && landingWidth > 0 && treadRun > 0) {
    const headerToWall = landingWidth + (numTreadsUpper * treadRun);
    headerToWallInput.value = headerToWall.toFixed(2);
  }

  isUpdating = false;
  validateInputs();
}

headerToWallInput.addEventListener('input', function() {
  calculateUpperTreads();
  calculateLowerTreads();
});

landingWidthInput.addEventListener('input', function() {
  calculateUpperTreads();
  calculateLowerTreads();
});

landingDepthInput.addEventListener('input', function() {
  checkLandingSize();
});

treadWidthLowerInput.addEventListener('input', function() {
  checkLandingSize();
  calculateUpperTreads();
  calculateLowerTreads();
});

treadWidthUpperInput.addEventListener('input', checkLandingSize);

treadRunInput.addEventListener('input', function() {
  calculateUpperTreads();
  calculateLowerTreads();
});

totalRiseInput.addEventListener('input', function() {
  calculateLowerTreads();
  calculateStairRise();
});

numTreadsLowerInput.addEventListener('input', function() {
  calculateStairRise();
  validateInputs();
});

numTreadsUpperInput.addEventListener('input', function() {
  calculateStairRise();
  updateHeaderToWall();
  validateInputs();
});

function validateInputs() {
  let isValid = true;

  document.querySelectorAll('.error').forEach(e => e.style.display = 'none');

  const numTreadsLower = parseInt(numTreadsLowerInput.value);
  const numTreadsUpper = parseInt(numTreadsUpperInput.value);
  const totalTreads = numTreadsLower + numTreadsUpper;

  if (numTreadsLower < 1 || numTreadsLower > 22) {
    document.getElementById('treads-lower-error').textContent = 'Calculated value out of range (1-22). Adjust Total Rise or Header to Wall.';
    document.getElementById('treads-lower-error').style.display = 'block';
    isValid = false;
  }

  const headerToWall = parseFloat(headerToWallInput.value);
  if (headerToWall < 24 || headerToWall > 240) {
    document.getElementById('header-to-wall-error').textContent = 'Must be between 24" and 240"';
    document.getElementById('header-to-wall-error').style.display = 'block';
    isValid = false;
  }

  if (numTreadsUpper < 1 || numTreadsUpper > 22) {
    document.getElementById('treads-upper-error').textContent = 'Calculated value out of range (1-22). Adjust Header to Wall.';
    document.getElementById('treads-upper-error').style.display = 'block';
    isValid = false;
  }

  if (totalTreads > 30) {
    document.getElementById('treads-lower-error').textContent = 'Total treads cannot exceed 30';
    document.getElementById('treads-lower-error').style.display = 'block';
    isValid = false;
  }

  const treadWidthLower = parseFloat(treadWidthLowerInput.value);
  const treadWidthUpper = parseFloat(treadWidthUpperInput.value);

  if (treadWidthLower < 24 || treadWidthLower > 60) {
    document.getElementById('width-lower-error').textContent = 'Must be between 24" and 60"';
    document.getElementById('width-lower-error').style.display = 'block';
    isValid = false;
  }

  if (treadWidthUpper < 24 || treadWidthUpper > 60) {
    document.getElementById('width-upper-error').textContent = 'Must be between 24" and 60"';
    document.getElementById('width-upper-error').style.display = 'block';
    isValid = false;
  }

  const treadRun = parseFloat(treadRunInput.value);
  if (treadRun < 11 || treadRun > 13) {
    document.getElementById('tread-run-error').textContent = 'Must be between 11" and 13"';
    document.getElementById('tread-run-error').style.display = 'block';
    isValid = false;
  }

  const stairRise = parseFloat(stairRiseInput.value);
  const totalRise = parseFloat(totalRiseInput.value);

  if (totalRise <= 0 || isNaN(totalRise)) {
    document.getElementById('total-rise-error').textContent = 'Total rise must be positive';
    document.getElementById('total-rise-error').style.display = 'block';
    isValid = false;
  }

  if (stairRise < 6 || stairRise > 9) {
    document.getElementById('rise-error').textContent = 'Must be between 6" and 9"';
    document.getElementById('rise-error').style.display = 'block';
    isValid = false;
  }

  const landingWidth = parseFloat(landingWidthInput.value);
  const landingDepth = parseFloat(landingDepthInput.value);

  if (landingWidth < 24 || landingWidth > 120) {
    document.getElementById('landing-width-error').textContent = 'Must be between 24" and 120"';
    document.getElementById('landing-width-error').style.display = 'block';
    isValid = false;
  }

  if (landingDepth < 24 || landingDepth > 120) {
    document.getElementById('landing-depth-error').textContent = 'Must be between 24" and 120"';
    document.getElementById('landing-depth-error').style.display = 'block';
    isValid = false;
  }

  return isValid;
}

function createStairs() {
  if (!validateInputs()) {
    return;
  }

  const values = {
    num_treads_lower: parseInt(numTreadsLowerInput.value),
    num_treads_upper: parseInt(numTreadsUpperInput.value),
    header_to_wall: parseFloat(headerToWallInput.value),
    tread_width_lower: parseFloat(treadWidthLowerInput.value),
    tread_width_upper: parseFloat(treadWidthUpperInput.value),
    landing_width: parseFloat(landingWidthInput.value),
    landing_depth: parseFloat(landingDepthInput.value),
    tread_run: parseFloat(treadRunInput.value),
    stair_rise: parseFloat(stairRiseInput.value),
    total_rise: parseFloat(totalRiseInput.value),
    turn_direction: turnDirectionSelect.value,
    glass_railing: glassRailingSelect.value
  };

  window.location = 'skp:create_landing_90@' + JSON.stringify(values);
}

function cancel() {
  window.location = 'skp:cancel';
}

checkLandingSize();
calculateUpperTreads();

window.addEventListener('load', function() {
  setTimeout(function() {
    const bodyHeight = document.body.scrollHeight;
    const bodyWidth = document.body.scrollWidth;

    window.location = 'skp:resize_dialog@' + JSON.stringify({
      width: Math.max(600, bodyWidth),
      height: Math.max(600, bodyHeight)
    });
  }, 100);
});
