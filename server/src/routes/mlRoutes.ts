import { Router, Request, Response } from 'express';
import { FloodMLService } from '../services/floodMLService';

export const mlRouter = Router();

// GET /api/v1/ml: Machine Learning early warning & hazard forecasting
mlRouter.get('/', (req: Request, res: Response) => {
  try {
    const predictions = FloodMLService.getActiveHazardPredictions();
    res.json({
      success: true,
      service: 'ResQAI Machine Learning Inundation & Early Warning Engine',
      model: 'Calibrated Gradient-Boosted Hydrologic Classifier',
      activePredictionsCount: predictions.length,
      data: predictions,
      endpoints: {
        predictions: '/api/v1/ml/predictions',
        floodPrediction: '/api/v1/ml/flood-prediction',
        predict: 'POST /api/v1/ml/predict'
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/ml/flood-prediction: Alias to active predictions
mlRouter.get('/flood-prediction', (req: Request, res: Response) => {
  try {
    const predictions = FloodMLService.getActiveHazardPredictions();
    res.json({
      success: true,
      count: predictions.length,
      data: predictions
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/ml/predictions
 * PRD FR-32, FR-33, FR-34: Get real-time hazard predictions with truth badges, SHAP factors & uncertainty
 */
mlRouter.get('/predictions', (req: Request, res: Response) => {
  try {
    const predictions = FloodMLService.getActiveHazardPredictions();
    res.json({
      success: true,
      data: predictions,
      timestamp: new Date().toISOString()
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * POST /api/v1/ml/predict
 * PRD FR-33, FR-35: Run inference with custom hydrologic telemetry
 */
mlRouter.post('/predict', (req: Request, res: Response) => {
  try {
    const {
      regionId,
      regionName,
      rainfall48hMm,
      riverGaugeDeltaM,
      soilMoistureSaturationPct,
      drainageBottleneckIndex,
      elevationM,
      dataFreshnessTimestamp,
      timeWindowHours
    } = req.body;

    if (rainfall48hMm === undefined || riverGaugeDeltaM === undefined) {
      return res.status(400).json({
        success: false,
        error: 'Missing required telemetry inputs: rainfall48hMm and riverGaugeDeltaM are mandatory.'
      });
    }

    const prediction = FloodMLService.predictFloodRisk(
      regionId || 'custom-sector',
      regionName || 'Custom Evaluation Zone',
      {
        rainfall48hMm: Number(rainfall48hMm),
        riverGaugeDeltaM: Number(riverGaugeDeltaM),
        soilMoistureSaturationPct: Number(soilMoistureSaturationPct || 60),
        drainageBottleneckIndex: Number(drainageBottleneckIndex || 50),
        elevationM: Number(elevationM || 50),
        dataFreshnessTimestamp: dataFreshnessTimestamp || new Date().toISOString()
      },
      timeWindowHours ? Number(timeWindowHours) : 24
    );

    res.json({
      success: true,
      data: prediction
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/ml/monitoring
 * PRD FR-37: Model monitoring, PR curve, calibration plot, drift metrics, and held-out validation report
 */
mlRouter.get('/monitoring', (req: Request, res: Response) => {
  try {
    const metrics = FloodMLService.getModelMonitoringMetrics();
    res.json({
      success: true,
      data: metrics
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * POST /api/v1/ml/earthquake-inquiry
 * PRD FR-36: Earthquake non-goal refusal & seismic hazard zone exposure only
 */
mlRouter.post('/earthquake-inquiry', (req: Request, res: Response) => {
  try {
    const { locationName } = req.body;
    const result = FloodMLService.handleEarthquakeInquiry(locationName || 'Patna, Bihar');
    res.json({
      success: true,
      data: result
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
