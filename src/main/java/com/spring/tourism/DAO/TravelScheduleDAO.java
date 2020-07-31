package com.spring.tourism.DAO;

import com.spring.tourism.Entity.TravelStoke;
import com.spring.tourism.Entity.TravelStokeEntity;

import java.util.List;

public interface TravelScheduleDAO {
    List<TravelStokeEntity> getTravelStokeByTravelId(String travelId);
}
