Step 1: Comment the  "ClassificationEnsemble Predict" block located at the bottom right of the canvas below the AI Decision Engine statement (click the block > click on the 3 dots that pops-up around the block > select the % symbol)

Step 2: set required parameters(optional)

Step 3: run the simulation

Step 4: minimize the Simulink canvas, copy and paste exactly the code below to the command window of your MATLAB environment and click enter to run the code.

% 1. Extract raw numeric data 
try
    V_raw = out.V_data.Data;
    I_raw = out.I_data.Data;
    Label_raw = out.Fault_Label.Data;
catch
    V_raw = out.V_data;
    I_raw = out.I_data;
    Label_raw = out.Fault_Label;
end

% 2. Force the data into standard 1D double-precision columns
V_col = double(V_raw(:));
I_col = double(I_raw(:));
Label_col = double(Label_raw(:));

% 3. Rebuild the standardized MATLAB Table
gridData = table(V_col, I_col, Label_col, 'VariableNames', {'Voltage', 'Current', 'FaultLabel'});

% 4. Train the Random Forest Model
disp('Training Random Forest Model... Please wait.');
rfModel = fitcensemble(gridData, 'FaultLabel', 'Method', 'Bag');

disp('Training Complete. Model details:');
disp(rfModel);

% 5. Save the trained model to the workspace for Simulink integration
saveLearnerForCoder(rfModel, 'Trained_RF_Model');


step 5: return to your Simulink canvas


Step 6: UNDO the commenting of the "ClassificationEnsemble Predict" block (click the block > click on the 3 dots that pops-up around the block > select the % symbol)


Step 5: double click the "ClassificationEnsemble Predict" block
 > type in rfModel in the "Select trained machine learning mode" comment box > click ok

Step 6: Run the simulation again

Step 7: Visualize output from all labeled scopes