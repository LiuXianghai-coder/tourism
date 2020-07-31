package com.spring.tourism.DAO;

import com.spring.tourism.Entity.TravelSimpleEntity;

import java.util.List;

public interface TravelSimpleDAO {
    TravelSimpleEntity getTravelSimpleEntityById(String travelId);

    List<TravelSimpleEntity> getTravelSimpleEntityList(int start, int size);
}
