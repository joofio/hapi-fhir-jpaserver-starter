var dataTableInitialized = false; // Flag to track DataTable initialization
var t; // DataTable instance
var appBaseUrl = "";

// Function to initialize or reinitialize the DataTable
function initializeDataTable() {
  // Check if the DataTable is already initialized
  if ($.fn.dataTable.isDataTable('#prod-table')) {
    // If already initialized, destroy it before reinitializing
    t = $('#prod-table').DataTable(); // Reference the existing DataTable instance
    t.destroy();
  }

  // Initialize the DataTable with the desired configuration
  t = $('#prod-table').DataTable({
    language: {

     search: "Procurar:", // Replace "Search" with "Procurar" or any other text
      info: 'A mostrar _START_ a _END_ de _TOTAL_ registos',
      infoEmpty: 'Sem conceitos para mostrar',
      infoFiltered: ' - friltrado de _MAX_ registos',
      lengthMenu:
      'Mostrar <select>' +
      '<option value="10">10</option>' +
      '<option value="20">20</option>' +
      '<option value="30">30</option>' +
      '<option value="40">40</option>' +
      '<option value="50">50</option>' +
      '</select> registos',
      entries: {
        _: 'registos',
        1: 'Registo'
    }
  
    }
  });
}



document.addEventListener('DOMContentLoaded', async function () {
  // Fetch the configuration from config.json
  fetch('config.json')
    .then((response) => response.json())
    .then((config) => {
      var baseurl = config.server_url;
   //   var url = baseurl + '/CodeSystem?_revinclude=ConceptMap:source-group-system&_format=json&_count=20000';
       var url = baseurl + '/ConceptMap?_format=json&_count=20000';

      console.log(url);
      var productFormatType = document.getElementById('productFormatType');

      // Initialize DataTable
      initializeDataTable();
      console.log("run initializeDataTable");


      //// Fetch and process the data
       getDataToProcess(url, false) // Set true for Bundle of Bundles
         .then(data => processData(data, baseurl))
         .catch((error) => console.error('Error processing data:', error));
    })
    .catch((error) => console.error('Error fetching configuration:', error));
});



async function getDataToProcess(url, isBundleOfBundles) {
  const response = await fetch(url);
  const data = await response.json();

  if (isBundleOfBundles) {
    // Process a Bundle of Bundles
    return data.entry
      .map(bundle => bundle.resource.entry)
      .flat()
      .map(entry => entry.resource);
  } else {
    // Process a single Bundle
    return data.entry.map(entry => entry.resource);
  }
}


async function processData(data, baseurl) {
  var processingModal = document.getElementById('processingModal');
  processingModal.style.display = 'block'; // Show the modal
  var totalCount = data.length;
  console.log(totalCount);
  console.log(data);
  for (var i = 0; i < totalCount; i++) {
    //    await new Promise(resolve => setTimeout(resolve, 10));
    bid= data[i].id;
    console.log(data[i].id);

    var resource = data[i];

    if (resource["resourceType"]=="ConceptMap" ) {
      console.log(resource);

      var current_row = [];

     
      try {
        current_row.push(
          '<a target="_blank" href="'+ baseurl + '/ConceptMap/' + data[i].id + '">'+data[i].id+'</a> <br>' 
        )
      //  current_row.push(data[i].id);
      } catch (error) {
        current_row.push(error);
      }




      try {
        current_row.push( resource.title );
      } catch (error) {
        current_row.push(error);
      }


      try {
        current_row.push ( resource.group[0].element.length );
      } catch (error) {
        current_row.push(error);
      }



      try {
        current_row.push(
          '<a target="_blank" href="./visualiser/viz-index.html?url=' + baseurl + '/ConceptMap/' + data[i].id + '">Ver</a> <br>' )
        } catch (error) {
          current_row.push(error);
        }
      t.row.add(current_row);

      console.log(current_row);
      // Update progress indicator
      progressIndicator.innerText = 'Processing product ' + (i + 1) + ' of ' + totalCount + '...';
    }
  }

  // Hide the progress indicator after processing
  processingModal.style.display = 'none'; // Hide the modal

  // Draw the DataTable after all data is added
  t.draw();
}
