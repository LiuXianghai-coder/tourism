package com.spring.tourism.Repository;

import com.spring.tourism.Entity.RaiderDetail;
import com.spring.tourism.Entity.RaiderDetailPK;
import org.springframework.data.repository.CrudRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface RaiderDetailRepository extends CrudRepository<RaiderDetail, RaiderDetailPK> {
    List<RaiderDetail> getRaiderDetailsByRaiderId(String raiderId);

    List<RaiderDetail> getRaiderDetailsByRaiderIdOrderByRaiderStep(String raiderId);
}
