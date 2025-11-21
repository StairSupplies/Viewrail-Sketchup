let isUpdating = false;

const system_type = document.getElementById('system_type');
const numTreadsInput = document.getElementById('num_treads');
const treadRunInput = document.getElementById('tread_run');
const treadWidthInput = document.getElementById('tread_width');
const totalTreadRunInput = document.getElementById('total_tread_run');
const stairRiseInput = document.getElementById('stair_rise');
const totalRiseInput = document.getElementById('total_rise');
const glassRailingSelect = document.getElementById('glass_railing');

function calculateTotalTreadRun() {
  if (isUpdating) return;
  isUpdating = true;

  const numTreads = parseInt(numTreadsInput.value) || 0;
  const treadRun = parseFloat(treadRunInput.value) || 0;

  if (numTreads > 0 && treadRun > 0) {
    const totalTreadRun = numTreads * treadRun;
    totalTreadRunInput.value = totalTreadRun.toFixed(2);
  }

  isUpdating = false;
  validateInputs();
}

function calculateStairRise() {
  if (isUpdating) return;
  isUpdating = true;

  const numTreads = parseInt(numTreadsInput.value) || 0;
  const totalRise = parseFloat(totalRiseInput.value) || 0;

  if (numTreads > 0 && totalRise > 0) {
    const stairRise = totalRise / (numTreads + 1);
    stairRiseInput.value = stairRise.toFixed(2);
  }

  isUpdating = false;
  validateInputs();
}

function validateInputs() {
  let isValid = true;

  document.querySelectorAll('.error').forEach(e => e.style.display = 'none');

  const numTreads = parseInt(numTreadsInput.value);
  const treadRun = parseFloat(treadRunInput.value);
  const treadWidth = parseFloat(treadWidthInput.value);

  if (numTreads < 1 || numTreads > 22) {
    document.getElementById('treads-error').textContent = 'Must be between 1 and 22';
    document.getElementById('treads-error').style.display = 'block';
    isValid = false;
  }

  if (treadRun < 11 || treadRun > 13) {
    document.getElementById('tread-run-error').textContent = 'Must be between 11" and 13"';
    document.getElementById('tread-run-error').style.display = 'block';
    isValid = false;
  }

  if (treadWidth < 24 || treadWidth > 60) {
    document.getElementById('tread-width-error').textContent = 'Must be between 24" and 60"';
    document.getElementById('tread-width-error').style.display = 'block';
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
    stair_type: system_type.value,
    num_treads: parseInt(document.getElementById('num_treads').value),
    tread_run: parseFloat(document.getElementById('tread_run').value),
    tread_width: parseFloat(document.getElementById('tread_width').value),
    total_tread_run: parseFloat(document.getElementById('total_tread_run').value),
    stair_rise: parseFloat(document.getElementById('stair_rise').value),
    total_rise: parseFloat(document.getElementById('total_rise').value),
    glass_railing: document.getElementById('glass_railing').value
  };

  window.location = 'skp:create_stairs@' + JSON.stringify(values);
}

function cancel() {
  window.location = 'skp:cancel';
}

numTreadsInput.addEventListener('change', function() {
  calculateTotalTreadRun();
  calculateStairRise();
});
treadRunInput.addEventListener('change', calculateTotalTreadRun);
treadWidthInput.addEventListener('change', validateInputs);
totalRiseInput.addEventListener('change', calculateStairRise);

calculateTotalTreadRun();
calculateStairRise();

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
