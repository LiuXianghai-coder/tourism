package com.spring.tourism.DAO;

import com.spring.tourism.Entity.TravelOrder;
import org.springframework.lang.NonNull;

import java.util.List;

public interface TravelOrderDAO {
    List<TravelOrder> getAllTravelOrders(@NonNull String userId);

    List<TravelOrder> getWillTravelOrders(@NonNull String userId);

    List<TravelOrder> getHasTravelOrders(@NonNull String userId);

    List<TravelOrder> getAllSaveTravelOrders(@NonNull String userId);
}
