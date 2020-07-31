package com.spring.tourism.Entity;

import javax.persistence.Column;
import javax.persistence.Id;
import java.io.Serializable;

public class RaiderDetailPK implements Serializable {
    private String raiderId;

    private Integer raiderStep;

    @Id
    @Column(name = "raider_id")
    public String getRaiderId() {
        return raiderId;
    }

    public void setRaiderId(String raiderId) {
        this.raiderId = raiderId;
    }

    @Id
    @Column(name = "raider_step")
    public Integer getRaiderStep() {
        return raiderStep;
    }

    public void setRaiderStep(Integer raiderStep) {
        this.raiderStep = raiderStep;
    }
}
