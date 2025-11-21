let isUpdating = false;

const numTreadsLowerInput = document.getElementById('num_treads_lower');
const numTreadsMiddleInput = document.getElementById('num_treads_middle');
const numTreadsUpperInput = document.getElementById('num_treads_upper');
const headerToWallInput = document.getElementById('header_to_wall');
const wallToWallInput = document.getElementById('wall_to_wall');
const treadWidthLowerInput = document.getElementById('tread_width_lower');
const treadWidthMiddleInput = document.getElementById('tread_width_middle');
const treadWidthUpperInput = document.getElementById('tread_width_upper');
const treadRunInput = document.getElementById('tread_run');
const totalRiseInput = document.getElementById('total_rise');
const stairRiseInput = document.getElementById('stair_rise');
const turnDirectionSelect = document.getElementById('turn_direction');
const glassRailingSelect = document.getElementById('glass_railing');

const maxTreadsUpperHS = 12;
const maxTreadsLowerHS = 14;
const maxTreadsZStringer = 9;

let lowerLandingWidth = 36.0;
let lowerLandingDepth = 36.0;
let upperLandingDepth = 36.0;
let upperLandingWidth = 36.0;

function calculateUpperTreads() {
  const headerToWall = parseFloat(headerToWallInput.value);
  const treadRun = parseFloat(treadRunInput.value) || 11;

  if (headerToWall > 36 && treadRun > 10.9) {
    const minUpperLandingWidth = parseFloat(treadWidthMiddleInput.value) || 36;
    const availableRun = headerToWall - minUpperLandingWidth;
    const upperTreads = Math.floor(availableRun / treadRun);

    const validUpperTreads = Math.max(1, Math.min(maxTreadsUpperHS, upperTreads));
    numTreadsUpperInput.value = validUpperTreads;
    console.log("Upper Treads: " + validUpperTreads);
    const usedRun = (validUpperTreads * treadRun);
    upperLandingWidth = headerToWall - usedRun;
    console.log("Upper Landing Width: " + upperLandingWidth);
  }
}

function calculateMiddleTreads() {
  const wallToWall = parseFloat(wallToWallInput.value) || 0;
  const treadRun = parseFloat(treadRunInput.value) || 11;

  if (wallToWall > 0 && treadRun > 0) {
    const minLowerLandingWidth = parseFloat(treadWidthLowerInput.value) || 36;
    const minUpperLandingDepth = parseFloat(treadWidthUpperInput.value) || 36;
    const treadWidthMiddle = parseFloat(treadWidthMiddleInput.value) || 36;

    const availableRun = wallToWall - minLowerLandingWidth - minUpperLandingDepth;
    const middleTreads = Math.floor(availableRun / treadRun);

    const validMiddleTreads = Math.max(1, Math.min(maxTreadsZStringer, middleTreads));
    numTreadsMiddleInput.value = validMiddleTreads;
    console.log("Middle Treads: " + validMiddleTreads);
    const usedRun = (validMiddleTreads * treadRun);
    const remainingRun = wallToWall - usedRun;
    const landingAdjustment = remainingRun - minLowerLandingWidth - minUpperLandingDepth;
    lowerLandingWidth = minLowerLandingWidth + landingAdjustment;
    console.log("Lower Landing Width: " + lowerLandingWidth);
    lowerLandingDepth = treadWidthMiddle;
  }
}

function calculateLowerTreads() {
  const totalRise = parseFloat(totalRiseInput.value) || 0;
  let numTreadsLower = parseInt(numTreadsLowerInput.value) || 0;
  const numTreadsMiddle = parseInt(numTreadsMiddleInput.value) || 0;
  const numTreadsUpper = parseInt(numTreadsUpperInput.value) || 0;

  if (totalRise > 0) {
    const totalTreads = numTreadsLower + numTreadsMiddle + numTreadsUpper;
    const calculatedRise = totalRise / (totalTreads + 3);

    if (calculatedRise > 9) {
      while (numTreadsLower < maxTreadsLowerHS) {
        numTreadsLower++;
        const newTotalTreads = numTreadsLower + numTreadsMiddle + numTreadsUpper;
        const newRise = totalRise / (newTotalTreads + 3);
        if (newRise <= 9) break;
      }
    } else if (calculatedRise < 6) {
      while (numTreadsLower > 1) {
        numTreadsLower--;
        const newTotalTreads = numTreadsLower + numTreadsMiddle + numTreadsUpper;
        const newRise = totalRise / (newTotalTreads + 3);
        if (newRise >= 6) break;
      }
    }

    if (numTreadsLower !== parseInt(numTreadsLowerInput.value)) {
      numTreadsLowerInput.value = numTreadsLower;
    }
    console.log("Lower Treads: " + numTreadsLower);
  }
}

function calculateStairRise() {
  if (isUpdating) return;
  isUpdating = true;

  const numTreadsLower = parseInt(numTreadsLowerInput.value) || 0;
  const numTreadsMiddle = parseInt(numTreadsMiddleInput.value) || 0;
  const numTreadsUpper = parseInt(numTreadsUpperInput.value) || 0;
  const totalTreads = numTreadsLower + numTreadsMiddle + numTreadsUpper;
  const totalRise = parseFloat(totalRiseInput.value) || 0;

  if (totalTreads > 0 && totalRise > 0) {
    const stairRise = totalRise / (totalTreads + 3);
    stairRiseInput.value = stairRise.toFixed(2);
  }

  isUpdating = false;
}

function updateHeaderToWall() {
  if (isUpdating) return;
  isUpdating = true;

  const numTreadsUpper = parseInt(numTreadsUpperInput.value) || 0;
  const minLandingWidth = parseFloat(treadWidthMiddleInput.value) || 36;
  const treadRun = parseFloat(treadRunInput.value) || 11;

  if (numTreadsUpper > 0) {
    const headerToWall = minLandingWidth + (numTreadsUpper * treadRun);
    headerToWallInput.value = parseFloat(headerToWall);
  }

  isUpdating = false;
}

function updateWallToWall() {
  if (isUpdating) return;
  isUpdating = true;

  const numTreadsMiddle = parseInt(numTreadsMiddleInput.value) || 0;
  const treadRun = parseFloat(treadRunInput.value) || 11;

  if (numTreadsMiddle > 0) {
    const wallToWall = lowerLandingWidth + upperLandingDepth + (numTreadsMiddle * treadRun);
    wallToWallInput.value = wallToWall.toFixed(2);
  }

  isUpdating = false;
}

function updateStairsAndLandings() {
  calculateUpperTreads();
  calculateMiddleTreads();
  calculateLowerTreads();
  calculateStairRise();
  validateInputs();
}

treadWidthLowerInput.addEventListener('input', function() {
  updateStairsAndLandings();
});

treadWidthMiddleInput.addEventListener('input', function() {
  updateStairsAndLandings();
});

treadWidthUpperInput.addEventListener('input', function() {
  updateStairsAndLandings();
});

treadRunInput.addEventListener('input', function() {
  updateStairsAndLandings();
});

wallToWallInput.addEventListener('input', function() {
  updateStairsAndLandings();
});

headerToWallInput.addEventListener('input', function() {
  updateStairsAndLandings();
});

totalRiseInput.addEventListener('input', function() {
  updateStairsAndLandings();
});

numTreadsUpperInput.addEventListener('input', function() {
  updateHeaderToWall();
  updateStairsAndLandings();
  validateInputs();
});

numTreadsMiddleInput.addEventListener('input', function() {
  updateWallToWall();
  updateStairsAndLandings();
  validateInputs();
});

numTreadsLowerInput.addEventListener('input', function() {
  updateStairsAndLandings();
  validateInputs();
});

function validateInputs() {
  let isValid = true;

  document.querySelectorAll('.error').forEach(e => e.style.display = 'none');

  const numTreadsLower = parseInt(numTreadsLowerInput.value);
  const numTreadsMiddle = parseInt(numTreadsMiddleInput.value);
  const numTreadsUpper = parseInt(numTreadsUpperInput.value);
  const totalTreads = numTreadsLower + numTreadsMiddle + numTreadsUpper;

  if (numTreadsLower < 1 || numTreadsLower > 22) {
    document.getElementById('treads-lower-error').textContent = 'Must be between 1 and 22';
    document.getElementById('treads-lower-error').style.display = 'block';
    isValid = false;
  }

  if (numTreadsMiddle < 1 || numTreadsMiddle > 22) {
    document.getElementById('treads-middle-error').textContent = 'Calculated value out of range (1-22). Adjust Wall to Wall.';
    document.getElementById('treads-middle-error').style.display = 'block';
    isValid = false;
  }

  if (numTreadsUpper < 1 || numTreadsUpper > 22) {
    document.getElementById('treads-upper-error').textContent = 'Must be between 1 and 22';
    document.getElementById('treads-upper-error').style.display = 'block';
    isValid = false;
  }

  const headerToWall = parseFloat(headerToWallInput.value);
  if (headerToWall < 24 || headerToWall > 240) {
    document.getElementById('header-to-wall-error').textContent = 'Must be between 24" and 240"';
    document.getElementById('header-to-wall-error').style.display = 'block';
    isValid = false;
  }

  const wallToWall = parseFloat(wallToWallInput.value);
  if (wallToWall < 48 || wallToWall > 240) {
    document.getElementById('wall-to-wall-error').textContent = 'Must be between 48" and 240"';
    document.getElementById('wall-to-wall-error').style.display = 'block';
    isValid = false;
  }

  const treadWidthLower = parseFloat(treadWidthLowerInput.value);
  const treadWidthMiddle = parseFloat(treadWidthMiddleInput.value);
  const treadWidthUpper = parseFloat(treadWidthUpperInput.value);

  if (treadWidthLower < 24 || treadWidthLower > 60) {
    document.getElementById('width-lower-error').textContent = 'Must be between 24" and 60"';
    document.getElementById('width-lower-error').style.display = 'block';
    isValid = false;
  }

  if (treadWidthMiddle < 24 || treadWidthMiddle > 60) {
    document.getElementById('width-middle-error').textContent = 'Must be between 24" and 60"';
    document.getElementById('width-middle-error').style.display = 'block';
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

  return isValid;
}

function createStairs() {
  if (!validateInputs()) {
    return;
  }

  const values = {
    num_treads_lower: parseInt(numTreadsLowerInput.value),
    num_treads_middle: parseInt(numTreadsMiddleInput.value),
    num_treads_upper: parseInt(numTreadsUpperInput.value),
    header_to_wall: parseFloat(headerToWallInput.value),
    wall_to_wall: parseFloat(wallToWallInput.value),
    tread_width_lower: parseFloat(treadWidthLowerInput.value),
    tread_width_middle: parseFloat(treadWidthMiddleInput.value),
    tread_width_upper: parseFloat(treadWidthUpperInput.value),
    lower_landing_width: lowerLandingWidth,
    lower_landing_depth: lowerLandingDepth,
    upper_landing_width: upperLandingWidth,
    upper_landing_depth: upperLandingDepth,
    tread_run: parseFloat(treadRunInput.value),
    stair_rise: parseFloat(stairRiseInput.value),
    total_rise: parseFloat(totalRiseInput.value),
    turn_direction: turnDirectionSelect.value,
    glass_railing: glassRailingSelect.value
  };

  window.location = 'skp:create_u_stairs@' + JSON.stringify(values);
}

function cancel() {
  window.location = 'skp:cancel';
}

updateStairsAndLandings();

window.addEventListener('load', function() {
  setTimeout(function() {
    const bodyHeight = document.body.scrollHeight;
    const bodyWidth = document.body.scrollWidth;

    window.location = 'skp:resize_dialog@' + JSON.stringify({
      width: Math.max(650, bodyWidth + 20),
      height: Math.max(700, bodyHeight + 40)
    });
  }, 100);
});
